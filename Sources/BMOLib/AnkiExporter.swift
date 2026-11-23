import Foundation
import AppKit

/// Builds Anki's text-import format (Anki: File → Import). The header syntax
/// needs Anki 2.1.55+ — see docs.ankiweb.net → Importing → Text Files.
/// Extension of the export file. Anki's importer reads both identically —
/// the choice only affects how the file looks in Finder and what opens it.
enum AnkiFileFormat: String, CaseIterable, Identifiable, Sendable {
    case txt
    case tsv

    var id: String { rawValue }
    var label: String { ".\(rawValue)" }
}

enum AnkiExporter {
    static let defaultDeckName = "Dansk::fraSig"
    /// Anki's stock note type, present in every collection. Anki localizes its
    /// name when a collection is created; if it's named differently the import
    /// dialog lets the user pick it, so this isn't a setting.
    static let noteType = "Basic"
    static let tag = "fraSig"

    /// Columns: Front (Danish), Back (English + optional IPA), tags, GUID.
    /// The GUID column is what makes re-importing a card update the existing
    /// note instead of adding a duplicate. With `includeWordClass`, a short
    /// card also gets its word classes ("verb", "noun"…) as extra tags —
    /// see `tags(for:includeWordClass:)`.
    static func makeFile(cards: [AnkiCard], deck: String, includeIPA: Bool, includeWordClass: Bool = false) -> String {
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
                tags(for: card, includeWordClass: includeWordClass),
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

    /// Space-separated, as Anki expects. Cards are Danish-front, so the
    /// card's saved Danish classes (Wiktionary, every reading: "adjective
    /// verb") win; the English side's class is the fallback when there are
    /// none (a phrase, no entry, or the lookup failed).
    static func tags(for card: AnkiCard, includeWordClass: Bool) -> String {
        guard includeWordClass else { return tag }
        let danishClasses = card.danishWordClasses ?? []
        let classes = danishClasses.isEmpty
            ? WordClassTagger.wordClass(english: card.english).map { [$0] } ?? []
            : danishClasses
        return ([tag] + classes.map(\.label)).joined(separator: " ")
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

    /// `<stem>.<ext>` in `directory`, or `<stem>-2.<ext>`, `-3`… when taken, so
    /// two exports in the same minute never overwrite each other.
    static func uniqueFileURL(in directory: URL, date: Date, format: AnkiFileFormat = .txt) -> URL {
        let stem = fileStem(for: date)
        let ext = format.rawValue
        var url = directory.appendingPathComponent("\(stem).\(ext)")
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(stem)-\(suffix).\(ext)")
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
    /// Set after an export in which some cards couldn't get their Danish
    /// word types because Wiktionary didn't answer. Informational: the
    /// export itself succeeded, and those cards are retried next time.
    @Published private(set) var notice: String?

    private let phoneticsService: PhoneticsService
    private let danishWordClassService: DanishWordClassService

    /// Both services default to the real ones; #Preview passes mocks so
    /// Xcode Canvas never shells out to a subprocess or hits Wiktionary.
    init(
        phoneticsService: PhoneticsService = PhoneticsService(),
        danishWordClassService: DanishWordClassService = DanishWordClassService()
    ) {
        self.phoneticsService = phoneticsService
        self.danishWordClassService = danishWordClassService
    }

    func exportPending() async {
        guard !isExporting else { return }
        let settings = AppSettings.shared
        var cards = settings.ankiCards.pending
        guard !cards.isEmpty else { return }

        isExporting = true
        errorMessage = nil
        notice = nil
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

        var unavailable = 0
        if settings.showWordClass {
            unavailable = await fillDanishWordClasses(in: &cards) { classes, id in
                settings.ankiCards.setDanishWordClasses(classes, forCardID: id)
            }
        }

        do {
            let downloads = try FileManager.default.url(
                for: .downloadsDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let url = AnkiExporter.uniqueFileURL(in: downloads, date: Date(), format: settings.ankiFileFormat)
            let contents = AnkiExporter.makeFile(
                cards: cards,
                deck: settings.ankiDeckName,
                includeIPA: includeIPA,
                includeWordClass: settings.showWordClass
            )
            try contents.write(to: url, atomically: true, encoding: .utf8)
            // Only after the write succeeds, so a failed export leaves the
            // cards pending for the next attempt.
            settings.ankiCards.markExported(ids: Set(cards.map(\.id)))
            notice = Self.unavailableNotice(count: unavailable)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = "Couldn't save the export file: \(error.localizedDescription)"
        }
    }

    /// Looks up Danish word classes for cards that have none saved, saving
    /// each answer through `save` so a card hits Wiktionary at most once ever.
    /// One request at a time, to stay polite to Wikimedia.
    ///
    /// After the first failed lookup, the rest are skipped: if Wiktionary is
    /// down or hanging, each attempt would cost a full timeout. Returns how
    /// many cards that could have had Danish types didn't get them because of
    /// that (they fall back to the English tag and are retried next export).
    func fillDanishWordClasses(
        in cards: inout [AnkiCard],
        save: ([WordClass], UUID) -> Void
    ) async -> Int {
        var unavailable = 0
        var wiktionaryDown = false
        for index in cards.indices where cards[index].danishWordClasses == nil {
            if wiktionaryDown {
                // Phrases were never going to be looked up, so don't count them.
                if DanishWordClassService.query(for: cards[index].danish) != nil {
                    unavailable += 1
                }
                continue
            }
            switch await danishWordClassService.lookup(cards[index].danish) {
            case .found(let classes):
                cards[index].danishWordClasses = classes
                save(classes, cards[index].id)
            case .failed:
                wiktionaryDown = true
                unavailable += 1
            case .notFound, .notApplicable:
                break
            }
        }
        return unavailable
    }

    static func unavailableNotice(count: Int) -> String? {
        guard count > 0 else { return nil }
        let cards = count == 1 ? "1 card" : "\(count) cards"
        return "Wiktionary didn't respond, so \(cards) got the English word type instead. "
            + "The Danish types will be added on the next export."
    }
}
