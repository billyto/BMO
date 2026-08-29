import Foundation

// MARK: - Phonetics Error

enum PhoneticsError: Error, Equatable {
    case emptyText
    case toolNotInstalled
    case processFailed
}

// MARK: - espeak-ng location

/// espeak-ng isn't guaranteed to be on PATH for GUI apps — same class of
/// problem as DEEPL_API_KEY (launchd's PATH is minimal for GUI-launched
/// processes) — so both the availability check and the runner look at the
/// common Homebrew install locations directly rather than relying on
/// `Process`/PATH lookup.
enum EspeakNG {
    static func executablePath() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/espeak-ng",  // Apple Silicon Homebrew
            "/usr/local/bin/espeak-ng",     // Intel Homebrew
            "/usr/bin/espeak-ng"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    static var isInstalled: Bool {
        executablePath() != nil
    }
}

// MARK: - Phonetics Runner Protocol

protocol PhoneticsRunner: Sendable {
    /// Returns an IPA transcription of `text`. `language` is currently always
    /// `.danish` — matches the app's existing Danish-only TTS scope — but is
    /// threaded through so the espeak-ng voice code isn't hardcoded deeper in.
    func run(text: String, language: Language) async throws -> String
}

// MARK: - espeak-ng-backed runner

struct ProcessPhoneticsRunner: PhoneticsRunner {
    private static func voiceCode(for language: Language) -> String {
        switch language {
        case .danish: return "da"
        case .english: return "en"
        }
    }

    func run(text: String, language: Language) async throws -> String {
        guard let executableURL = EspeakNG.executablePath() else {
            throw PhoneticsError.toolNotInstalled
        }

        let process = Process()
        process.executableURL = executableURL
        // Arguments passed as an array (not a shell string), so no quoting/
        // injection concerns regardless of what `text` contains.
        process.arguments = ["-v", Self.voiceCode(for: language), "--ipa", "-q", text]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        // /dev/null, not an unread Pipe() — an unread pipe's OS buffer (~64KB)
        // could fill and block the child on a stderr write while we're
        // blocked reading stdout below, deadlocking both sides.
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw PhoneticsError.toolNotInstalled
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PhoneticsError.processFailed
        }

        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !output.isEmpty else {
            throw PhoneticsError.processFailed
        }
        return output
    }
}

// MARK: - Phonetics Service

final class PhoneticsService: Sendable {
    private let runner: PhoneticsRunner

    init(runner: PhoneticsRunner = ProcessPhoneticsRunner()) {
        self.runner = runner
    }

    func ipa(for text: String, language: Language) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PhoneticsError.emptyText }
        return try await runner.run(text: trimmed, language: language)
    }
}

/// Resolves which of a translation's two texts is Danish — exactly one will
/// be, since the app only supports the DA/EN pair — or nil if neither side
/// does (shouldn't happen given that constraint, but keeps this total).
/// Shared by TranslatorViewModel.refreshDanishIPA and
/// TranslationResultViewModel.fetchDanishIPAIfNeeded so the popover and the
/// Services floating window can't drift on this logic.
func danishText(source: String, translated: String, from: Language, to: Language) -> String? {
    if from == .danish { return source }
    if to == .danish { return translated }
    return nil
}
