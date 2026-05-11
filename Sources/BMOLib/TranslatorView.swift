import SwiftUI
import AppKit
import AVFoundation

enum ActiveView: Equatable {
    case main
    case history
    case settings
}

struct TranslatorView: View {
    @StateObject private var viewModel: TranslatorViewModel

    init(translationService: TranslationService) {
        _viewModel = StateObject(wrappedValue: TranslatorViewModel(
            translationService: translationService
        ))
    }

    private static let viewSwitchAnimation: Animation = .easeInOut(duration: 0.22)

    var body: some View {
        ZStack {
            switch viewModel.activeView {
            case .main:
                MainView(viewModel: viewModel)
                    .transition(.move(edge: .leading))
            case .history:
                HistoryView(
                    onBack: { withAnimation(Self.viewSwitchAnimation) { viewModel.activeView = .main } },
                    onSelect: { item in
                        viewModel.restore(from: item)
                        withAnimation(Self.viewSwitchAnimation) { viewModel.activeView = .main }
                    }
                )
                .transition(.move(edge: .trailing))
            case .settings:
                SettingsView(
                    onBack: { withAnimation(Self.viewSwitchAnimation) { viewModel.activeView = .main } }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .frame(width: SigSpacing.popoverWidth, height: 400)
        .clipped()
    }
}

// MARK: - Main view

private struct MainView: View {
    @ObservedObject var viewModel: TranslatorViewModel
    @ObservedObject private var settings = AppSettings.shared

    private var showAutoTranslateHint: Bool {
        settings.autoTranslateEnabled && !viewModel.isInputBlank
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SigSpacing.sectionGap) {
            HeaderRow()
            LanguageBar(viewModel: viewModel)
            InputPanel(viewModel: viewModel)
                .onChange(of: viewModel.inputText) { _, _ in
                    viewModel.scheduleAutoTranslateIfNeeded()
                }
            VStack(spacing: 4) {
                TranslateButton(
                    action: { Task { await viewModel.translate() } },
                    isLoading: viewModel.isLoading,
                    disabled: viewModel.isInputBlank || viewModel.isLoading
                )
                if showAutoTranslateHint {
                    Text("Auto-translating as you type")
                        .font(.system(size: 10.5))
                        .foregroundColor(SigTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: showAutoTranslateHint)
            ResultPanel(viewModel: viewModel)
            Spacer(minLength: 0)
            FooterRow(viewModel: viewModel)
        }
        .padding(SigSpacing.panelPadding)
        .frame(width: SigSpacing.popoverWidth, height: 400)
        .background(SigTheme.surface)
    }
}

// MARK: - Header

private struct HeaderRow: View {
    var body: some View {
        // DeepL badge moved to Settings as the API-key status indicator.
        VStack(alignment: .leading, spacing: 3) {
            Text("Sig")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(SigTheme.textPrimary)
            Text("Min danske hjælper")
                .font(.system(size: 12))
                .foregroundColor(SigTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Language bar

private struct LanguageBar: View {
    @ObservedObject var viewModel: TranslatorViewModel

    var body: some View {
        HStack(spacing: 0) {
            LanguageChip(language: viewModel.sourceLanguage)
            SwapButton(action: viewModel.swapLanguages)
            LanguageChip(language: viewModel.targetLanguage)
        }
    }
}

private struct LanguageChip: View {
    let language: Language

    var body: some View {
        HStack(spacing: 5) {
            Text(language == .danish ? "🇩🇰" : "🇬🇧")
                .font(.system(size: 15))
            Text(language == .danish ? "Danish" : "English")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(SigTheme.textPrimary)
        }
        // Cross-fade the flag + label when the language flips so the chip
        // doesn't visibly snap during a swap.
        .id(language)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: language)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(SigTheme.chipBg)
        .cornerRadius(SigRadius.chip)
    }
}

private struct SwapButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @State private var rotation: Double = 0

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                rotation += 180
            }
            action()
        }) {
            Image(systemName: "arrow.2.squarepath")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(SigTheme.accent)
                .rotationEffect(.degrees(rotation))
                .frame(width: 32, height: 32)
                .background(Circle().fill(isHovered ? SigTheme.swapHoverBg : Color.clear))
                .scaleEffect(isHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .help("Swap languages")
    }
}

// MARK: - Input

private struct InputPanel: View {
    @ObservedObject var viewModel: TranslatorViewModel
    @FocusState private var isFocused: Bool

    private var inputBinding: Binding<String> {
        Binding(
            get: { viewModel.inputText },
            set: { viewModel.setInput($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    // Padding here is calibrated so the placeholder lines up with
                    // the first glyph of the underlying NSTextView (TextEditor's
                    // outer padding + NSTextView's internal text container inset).
                    Text("Type or paste Danish text…")
                        .font(.system(size: 14))
                        .foregroundColor(SigTheme.textMuted.opacity(0.7))
                        .padding(.horizontal, 13)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: inputBinding)
                    .font(.system(size: 14))
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.top, 9)
                    .padding(.bottom, 4)
                    .frame(minHeight: SigSpacing.inputMinHeight)
                    .tint(SigTheme.accent)
            }
            InputToolbar(viewModel: viewModel)
        }
        .background(SigTheme.inputBg)
        .clipShape(RoundedRectangle(cornerRadius: SigRadius.input))
        .overlay(
            RoundedRectangle(cornerRadius: SigRadius.input)
                .stroke(isFocused ? SigTheme.accent.opacity(0.55) : SigTheme.inputBorder, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

private struct InputToolbar: View {
    @ObservedObject var viewModel: TranslatorViewModel

    private var charLimit: Int { TranslatorViewModel.inputCharLimit }

    var body: some View {
        HStack(spacing: 6) {
            // Speak button — Danish-only since the existing TTS forces a Danish voice.
            if viewModel.sourceLanguage == .danish && !viewModel.inputText.isEmpty {
                IconButton(
                    systemName: viewModel.isSpeakingInput ? "speaker.wave.3.fill" : "speaker.wave.2",
                    tint: viewModel.isSpeakingInput ? SigTheme.accent : SigTheme.textMuted,
                    action: viewModel.speakInputDanish,
                    help: "Speak input"
                )
            }
            Spacer()
            Text("\(viewModel.inputText.count)/\(charLimit)")
                .font(.system(size: 10.5))
                .monospacedDigit()
                .foregroundColor(viewModel.inputText.count >= charLimit ? SigTheme.warn : SigTheme.textMuted)
            if !viewModel.inputText.isEmpty {
                IconButton(
                    systemName: "xmark.circle.fill",
                    tint: SigTheme.textMuted,
                    action: viewModel.clear,
                    help: "Clear (⌘K)"
                )
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .frame(height: 24)
    }
}

// MARK: - Translate button

private struct TranslateButton: View {
    let action: () -> Void
    let isLoading: Bool
    let disabled: Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    BouncingDots(color: .white)
                } else {
                    HStack(spacing: 7) {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                        Text("Translate")
                            .font(.system(size: 13.5, weight: .semibold))
                            .tracking(0.2)
                        Text("⌘↩")
                            .font(.system(size: 10.5))
                            .opacity(0.7)
                    }
                }
            }
            .foregroundColor(disabled ? SigTheme.buttonDisabledText : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SigSpacing.buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: SigRadius.input)
                    .fill(disabled ? SigTheme.buttonDisabledBg
                          : (isHovered ? SigTheme.buttonHover : SigTheme.buttonBg))
            )
            .offset(y: !disabled && isHovered ? -1 : 0)
            .shadow(
                color: disabled ? .clear : SigTheme.buttonBg.opacity(isHovered ? 0.4 : 0.18),
                radius: isHovered ? 10 : 4,
                x: 0,
                y: isHovered ? 3 : 1
            )
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = $0 }
        .keyboardShortcut(.return, modifiers: .command)
    }
}

// MARK: - Result panel

private struct ResultPanel: View {
    @ObservedObject var viewModel: TranslatorViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingResult()
            } else if let error = viewModel.errorMessage {
                ErrorResult(message: error)
            } else if viewModel.translatedText.isEmpty {
                EmptyResult()
            } else {
                FilledResult(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyResult: View {
    var body: some View {
        Text("Translation will appear here")
            .font(.system(size: 12))
            .foregroundColor(SigTheme.textMuted)
            .frame(maxWidth: .infinity, minHeight: SigSpacing.resultMinHeight)
            .overlay(
                RoundedRectangle(cornerRadius: SigRadius.input)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .foregroundColor(SigTheme.divider)
            )
    }
}

private struct LoadingResult: View {
    var body: some View {
        HStack(spacing: 8) {
            BouncingDots(color: SigTheme.textMuted)
            Text("Translating…")
                .font(.system(size: 12))
                .foregroundColor(SigTheme.textMuted)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: SigSpacing.resultMinHeight, alignment: .topLeading)
        .background(SigTheme.resultBg)
        .clipShape(RoundedRectangle(cornerRadius: SigRadius.input))
        .overlay(
            RoundedRectangle(cornerRadius: SigRadius.input)
                .stroke(SigTheme.resultBorder, lineWidth: 1.5)
        )
    }
}

private struct ErrorResult: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundColor(SigTheme.errorText)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(SigTheme.errorText)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: SigSpacing.resultMinHeight, alignment: .topLeading)
        .background(SigTheme.errorBg)
        .clipShape(RoundedRectangle(cornerRadius: SigRadius.input))
        .overlay(
            RoundedRectangle(cornerRadius: SigRadius.input)
                .stroke(SigTheme.errorBorder, lineWidth: 1.5)
        )
    }
}

private struct FilledResult: View {
    @ObservedObject var viewModel: TranslatorViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(viewModel.translatedText)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SigTheme.textPrimary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 3) {
                IconButton(
                    systemName: viewModel.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2",
                    tint: viewModel.isSpeaking ? SigTheme.accent : SigTheme.textMuted,
                    action: viewModel.speakDanish,
                    help: "Speak"
                )
                IconButton(
                    systemName: viewModel.isCopied ? "checkmark" : "doc.on.doc",
                    tint: viewModel.isCopied ? SigTheme.success : SigTheme.textMuted,
                    action: viewModel.copyTranslation,
                    help: "Copy"
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: SigSpacing.resultMinHeight, alignment: .topLeading)
        .background(SigTheme.resultBg)
        .clipShape(RoundedRectangle(cornerRadius: SigRadius.input))
        .overlay(
            RoundedRectangle(cornerRadius: SigRadius.input)
                .stroke(SigTheme.resultBorder, lineWidth: 1.5)
        )
    }
}

// MARK: - Footer

private struct FooterRow: View {
    @ObservedObject var viewModel: TranslatorViewModel

    private static let viewSwitchAnimation: Animation = .easeInOut(duration: 0.22)

    var body: some View {
        HStack {
            FooterButton(
                systemName: "clock",
                help: "History",
                isActive: viewModel.activeView == .history
            ) {
                withAnimation(Self.viewSwitchAnimation) { viewModel.activeView = .history }
            }
            Spacer()
            FooterButton(systemName: "gearshape", help: "Settings", isActive: false) {
                withAnimation(Self.viewSwitchAnimation) { viewModel.activeView = .settings }
            }
            FooterButton(systemName: "power", help: "Quit", isActive: false) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

private struct FooterButton: View {
    let systemName: String
    let help: String
    let isActive: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var foreground: Color {
        if isActive { return SigTheme.accent }
        return isHovered ? SigTheme.textPrimary : SigTheme.textMuted
    }

    private var background: Color {
        (isActive || isHovered) ? SigTheme.chipBg : .clear
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // ZStack forces the SF Symbol's geometric center onto the chip
                // center; .frame around an Image was centering each symbol's
                // bounding box, but clock / gearshape / power have different
                // visible glyph offsets within those boxes which made the row
                // look bottom-aligned.
                RoundedRectangle(cornerRadius: SigRadius.footerButton)
                    .fill(background)
                Image(systemName: systemName)
                    .font(.system(size: 13))
                    .imageScale(.medium)
                    .foregroundColor(foreground)
            }
            .frame(width: SigSpacing.footerButtonSize, height: SigSpacing.footerButtonSize)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

// MARK: - Shared bits

private struct IconButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void
    let help: String
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? SigTheme.chipBg.opacity(0.6) : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

private struct BouncingDots: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .opacity(animating ? 1 : 0.4)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.18),
                        value: animating
                    )
            }
        }
        .frame(height: 16)
        .onAppear { animating = true }
    }
}

@MainActor
class TranslatorViewModel: ObservableObject {
    /// Max chars the input field accepts. All write paths (TextEditor binding,
    /// swapLanguages, restore) must go through `setInput(_:)` so the limit can't
    /// be bypassed and leave the char counter wedged above the cap.
    static let inputCharLimit = 500

    @Published var inputText: String = ""
    @Published var translatedText: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var sourceLanguage: Language = .danish
    @Published var targetLanguage: Language = .english
    @Published var isSpeaking: Bool = false
    @Published var isSpeakingInput: Bool = false
    @Published var isCopied: Bool = false
    @Published var activeView: ActiveView = .main

    private let translationService: TranslationService
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechDelegate: SpeechDelegate?
    private var autoTranslateTask: Task<Void, Never>?
    private var copyResetTask: Task<Void, Never>?

    /// True when input is empty or only whitespace/newlines — used to disable
    /// the Translate button and short-circuit translate() so we don't send
    /// useless requests.
    var isInputBlank: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Programmatic input setter that enforces `inputCharLimit`. Use this from
    /// any code path that's not the TextEditor binding (e.g. swap, restore).
    func setInput(_ text: String) {
        inputText = String(text.prefix(Self.inputCharLimit))
    }

    init(translationService: TranslationService) {
        self.translationService = translationService
        speechDelegate = SpeechDelegate(viewModel: self)
        speechSynthesizer.delegate = speechDelegate
    }

    func speakDanish() {
        guard !translatedText.isEmpty else { return }

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            isSpeakingInput = false
            return
        }

        let utterance = AVSpeechUtterance(string: translatedText)
        utterance.voice = AVSpeechSynthesisVoice(language: "da-DK")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        isSpeaking = true
        speechSynthesizer.speak(utterance)
    }

    func speakInputDanish() {
        guard !inputText.isEmpty else { return }

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            isSpeakingInput = false
            return
        }

        let utterance = AVSpeechUtterance(string: inputText)
        utterance.voice = AVSpeechSynthesisVoice(language: "da-DK")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        isSpeakingInput = true
        speechSynthesizer.speak(utterance)
    }

    func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp

        // Optionally swap the text too. Translation results can exceed
        // inputCharLimit (DeepL doesn't promise length-preserving output), so
        // go through setInput to truncate rather than assign directly.
        if !translatedText.isEmpty {
            let tempText = inputText
            setInput(translatedText)
            translatedText = tempText
        }
    }

    func clear() {
        autoTranslateTask?.cancel()
        autoTranslateTask = nil
        copyResetTask?.cancel()
        copyResetTask = nil

        inputText = ""
        translatedText = ""
        errorMessage = nil
        isCopied = false

        // Stop any ongoing speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            isSpeakingInput = false
        }
    }

    func translate() async {
        guard !isInputBlank else { return }

        // Manual translate cancels any pending auto-translate so we don't
        // double-fire against the same input. Cancel-then-nil is safe here
        // because when translate() is called from within the auto-translate
        // task itself, scheduleAutoTranslateIfNeeded has already nil-ed the
        // reference (see the comment there) — so this is a no-op in that
        // path and won't trigger self-cancellation of the URLSession await.
        autoTranslateTask?.cancel()
        autoTranslateTask = nil

        isLoading = true
        errorMessage = nil
        translatedText = ""

        // Snapshot the inputs in case the user edits while the request is in flight.
        let source = inputText
        let from = sourceLanguage
        let to = targetLanguage

        do {
            let result = try await translationService.translate(text: source, from: from, to: to)
            translatedText = result
            AppSettings.shared.recordTranslation(source: source, translation: result, from: from, to: to)
        } catch let error as TranslationError {
            errorMessage = errorMessage(for: error)
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Schedule a translate after a 1s pause in typing. No-op when auto-translate
    /// is disabled or input is whitespace-only.
    func scheduleAutoTranslateIfNeeded() {
        autoTranslateTask?.cancel()
        guard AppSettings.shared.autoTranslateEnabled, !isInputBlank else {
            autoTranslateTask = nil
            return
        }
        autoTranslateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            // Release the self-reference BEFORE calling translate(). Otherwise
            // translate()'s autoTranslateTask?.cancel() cancels the very task
            // we're inside, and Swift's cancellation propagation makes the
            // upcoming URLSession await throw .cancelled — auto-translate would
            // silently fail with a "network error" message.
            self.autoTranslateTask = nil
            await self.translate()
        }
    }

    /// Restore a saved translation back into the editor — called from the History
    /// view when the user taps a row.
    func restore(from item: HistoryItem) {
        autoTranslateTask?.cancel()
        autoTranslateTask = nil
        // History items can hold source text that's longer than the current
        // input limit (e.g. limit lowered after the item was recorded), so go
        // through setInput rather than assigning directly.
        setInput(item.sourceText)
        translatedText = item.translatedText
        sourceLanguage = item.sourceLang
        targetLanguage = item.targetLang
        errorMessage = nil
        isCopied = false
    }

    /// Copy the current translation to the clipboard and flash `isCopied = true`
    /// for 1.8s so the result panel can swap its copy icon for a checkmark.
    func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translatedText, forType: .string)
        isCopied = true
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard let self, !Task.isCancelled else { return }
            self.isCopied = false
        }
    }

    private func errorMessage(for error: TranslationError) -> String {
        switch error {
        case .emptyText:
            return "Please enter some text to translate"
        case .invalidAPIKey:
            return "Invalid API key. Please check your DeepL API key."
        case .networkError:
            return "Network error. Please check your internet connection."
        case .quotaExceeded:
            return "Translation quota exceeded. Please try again later."
        case .invalidResponse:
            return "Invalid response from translation service."
        }
    }

    fileprivate func speechDidFinish() {
        isSpeaking = false
        isSpeakingInput = false
    }
}

final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    weak var viewModel: TranslatorViewModel?

    init(viewModel: TranslatorViewModel) {
        self.viewModel = viewModel
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            viewModel?.speechDidFinish()
        }
    }
}

// MARK: - Preview Support

#Preview("Default State") {
    TranslatorView(
        translationService: try! TranslationService(apiKey: "preview-key", networkClient: MockNetworkClient())
    )
}

#Preview("With Input Text") {
    let service = try! TranslationService(apiKey: "preview-key", networkClient: MockNetworkClient())
    TranslatorView(translationService: service)
}

// Mock NetworkClient for previews
final class MockNetworkClient: NetworkClient {
    func performRequest(url: URL, body: [String: String], headers: [String: String]) async throws -> DeepLResponse {
        // Simulate network delay for realistic preview
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Extract text from body to create mock translation
        let sourceText = body["text"] ?? "Hello"
        let targetLang = body["target_lang"] ?? "EN"

        let mockText = targetLang == "DA"
            ? "Dansk oversættelse af: \(sourceText)"
            : "English translation of: \(sourceText)"

        return DeepLResponse(
            translations: [
                Translation(text: mockText, detectedSourceLanguage: "DA")
            ]
        )
    }
}
