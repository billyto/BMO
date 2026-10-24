import Foundation
import AppKit

/// Builds Anki's text-import format (Anki: File → Import). The header syntax
/// needs Anki 2.1.55+ — see docs.ankiweb.net → Importing → Text Files.
enum AnkiExporter {
    static let defaultDeckName = "Dansk::fraSig"
    /// Anki's stock note type, present in every collection. Anki localizes its
    /// name when a collection is created; if it's named differently the import
    /// dialog lets the user pick it, so this isn't a setting.
    static let noteType = "Basic"
    static let tag = "fraSig"

    /// Columns: Front (Danish), Back (English + optional IPA), tags, GUID.
    /// The GUID column is what makes re-importing a card update the existing
    /// note instead of adding a duplicate.
    static func makeFile(cards: [AnkiCard], deck: String, includeIPA: Bool) -> String {
        var lines = [
            "#separator:tab",
            "#html:true",
            "#notetype:\(noteType)",
            "#deck:\(deckName(deck))",
            "#tags column:3",
            "#guid column:4",
        ]
        for card in cards {
            let fields = [
                escape(card.danish),
                back(for: card, includeIPA: includeIPA),
                tag,
                card.id.uuidString,
            ]
            lines.append(fields.joined(separator: "\t"))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Trimmed deck name with tabs/newlines (which would break the header
    /// line) flattened to spaces. Falls back to the default when blank.
    static func deckName(_ raw: String) -> String {
        let flattened = raw
            .replacingOccurrences(of: "\t", with: " ")
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return flattened.isEmpty ? defaultDeckName : flattened
    }

    static func back(for card: AnkiCard, includeIPA: Bool) -> String {
        let english = escape(card.english)
        guard includeIPA,
              let ipa = card.ipa?.trimmingCharacters(in: .whitespacesAndNewlines),
              !ipa.isEmpty else {
            return english
        }
        // espeak-ng prints bare IPA; wrap it in slashes unless it already has them.
        let wrapped = ipa.hasPrefix("/") ? ipa : "/\(ipa)/"
        return "\(english)<br><small>\(escape(wrapped))</small>"
    }

    /// Escapes a field for `#html:true`. `"` and `#` are escaped too: Anki's
    /// parser treats a field opening with `"` as quoted and a line opening
    /// with `#` as a comment, either of which would mangle the row. `&` must
    /// go first so the entities added after it aren't double-escaped.
    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "#", with: "&#35;")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "\t", with: " ")
    }

    static func fileStem(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "Sig-Anki-\(formatter.string(from: date))"
    }

    /// `<stem>.txt` in `directory`, or `<stem>-2.txt`, `-3`… when taken, so two
    /// exports in the same minute never overwrite each other.
    static func uniqueFileURL(in directory: URL, date: Date) -> URL {
        let stem = fileStem(for: date)
        var url = directory.appendingPathComponent("\(stem).txt")
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(stem)-\(suffix).txt")
            suffix += 1
        }
        return url
    }
}

// MARK: - Export flow

/// Drives the Anki list view's Export button: fills in missing IPA, writes the
/// file to Downloads, reveals it in Finder, then marks the cards exported.
/// Writes straight to Downloads rather than presenting an NSSavePanel — the
/// panel would take focus and close the `.transient` popover mid-export.
@MainActor
final class AnkiExportModel: ObservableObject {
    @Published private(set) var isExporting = false
    @Published private(set) var errorMessage: String?

    private let phoneticsService: PhoneticsService

    /// `phoneticsService` defaults to the real espeak-ng-backed one; #Preview
    /// passes a mock so Xcode Canvas never shells out to a real subprocess.
    init(phoneticsService: PhoneticsService = PhoneticsService()) {
        self.phoneticsService = phoneticsService
    }

    func exportPending() async {
        guard !isExporting else { return }
        let settings = AppSettings.shared
        var cards = settings.ankiCards.pending
        guard !cards.isEmpty else { return }

        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        let includeIPA = settings.ankiIncludeIPA
        if includeIPA && EspeakNG.isInstalled {
            for index in cards.indices where cards[index].ipa == nil {
                guard let ipa = try? await phoneticsService.ipa(for: cards[index].danish, language: .danish) else {
                    continue
                }
                cards[index].ipa = ipa
                settings.ankiCards.setIPA(ipa, forCardID: cards[index].id)
            }
        }

        do {
            let downloads = try FileManager.default.url(
                for: .downloadsDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let url = AnkiExporter.uniqueFileURL(in: downloads, date: Date())
            let contents = AnkiExporter.makeFile(cards: cards, deck: settings.ankiDeckName, includeIPA: includeIPA)
            try contents.write(to: url, atomically: true, encoding: .utf8)
            // Only after the write succeeds, so a failed export leaves the
            // cards pending for the next attempt.
            settings.ankiCards.markExported(ids: Set(cards.map(\.id)))
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = "Couldn't save the export file: \(error.localizedDescription)"
        }
    }
}
