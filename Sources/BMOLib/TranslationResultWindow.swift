import SwiftUI
import AppKit
import AVFoundation

@MainActor
class TranslationResultWindow: NSObject {
    private var window: NSWindow?
    private var autoCloseTimer: Timer?

    init(original: String, translated: String, detectedSource: Language? = nil) {
        super.init()
        setupWindow(original: original, translated: translated, detectedSource: detectedSource)
    }

    private func setupWindow(original: String, translated: String, detectedSource: Language?) {
        let contentView = TranslationResultView(
            original: original,
            translated: translated,
            detectedSource: detectedSource,
            onCopy: { [weak self] in
                self?.copyToClipboard(translated)
            },
            onClose: { [weak self] in
                self?.close()
            }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let win = NSWindow(contentViewController: hostingController)
        window = win

        win.styleMask = [.borderless, .nonactivatingPanel]
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        win.hasShadow = true
        win.isMovableByWindowBackground = true

        // Size to fit the SwiftUI content rather than guessing a fixed height —
        // translation length varies a lot and the new card layout grows
        // vertically with it. Using sizeThatFits(in:) forces SwiftUI to
        // measure synchronously against the width constraint; the bare
        // `.view.fittingSize` returns ~zero before the controller's view has
        // been attached, which would collapse our positioning math and let
        // the later auto-resize push the window into the bottom-right corner.
        let fittingSize = hostingController.sizeThatFits(in: NSSize(
            width: SigSpacing.popoverWidth,
            height: .greatestFiniteMagnitude
        ))
        win.setContentSize(fittingSize)

        // Position near mouse cursor — pick the screen the cursor is actually on
        // (NSScreen.main is the screen with key window, not the cursor's screen)
        // and clamp all four edges within its visibleFrame (excludes menu bar / Dock).
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        if let screenFrame = screen?.visibleFrame {
            let windowSize = win.frame.size
            var windowOrigin = mouseLocation
            windowOrigin.x += 20
            windowOrigin.y -= 40

            if windowOrigin.x + windowSize.width > screenFrame.maxX {
                windowOrigin.x = screenFrame.maxX - windowSize.width - 10
            }
            if windowOrigin.x < screenFrame.minX {
                windowOrigin.x = screenFrame.minX + 10
            }
            // setFrameTopLeftPoint treats y as the window's top edge.
            if windowOrigin.y > screenFrame.maxY {
                windowOrigin.y = screenFrame.maxY - 10
            }
            if windowOrigin.y - windowSize.height < screenFrame.minY {
                windowOrigin.y = screenFrame.minY + windowSize.height + 10
            }

            win.setFrameTopLeftPoint(windowOrigin)
        }

        let timeout = AppSettings.shared.effectiveTimeout
        if timeout > 0 {
            autoCloseTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.close()
                }
            }
        }
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func close() {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
        window?.close()
        window = nil
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // No beep — the SwiftUI checkmark flash is the feedback now.
    }
}

// MARK: - View

struct TranslationResultView: View {
    let original: String
    let translated: String
    /// What DeepL's `detected_source_language` came back as. Drives the
    /// direction label and per-side TTS voice. Nil means "we don't know"
    /// (rare — only when DeepL returned a language code outside DA/EN).
    let detectedSource: Language?
    let onCopy: () -> Void
    let onClose: () -> Void

    @StateObject private var viewModel = TranslationResultViewModel()
    @State private var isCopied = false
    @State private var copyResetTask: Task<Void, Never>?

    private var sourceLanguage: Language? { detectedSource }
    private var targetLanguage: Language? {
        guard let detectedSource else { return nil }
        // autoTranslate's contract: when source is English we re-translate to
        // Danish; everything else lands in English.
        return detectedSource == .english ? .danish : .english
    }

    private var directionLabel: String? {
        guard let source = sourceLanguage, let target = targetLanguage else { return nil }
        return "\(Self.flag(for: source))  →  \(Self.flag(for: target))"
    }

    private static func flag(for language: Language) -> String {
        switch language {
        case .danish: return "🇩🇰"
        case .english: return "🇬🇧"
        }
    }

    private static func voiceCode(for language: Language?) -> String {
        switch language {
        case .danish: return "da-DK"
        case .english, nil: return "en-US"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !original.isEmpty {
                originalRow
            }
            translationCard
        }
        .padding(SigSpacing.panelPadding - 2)
        .frame(width: SigSpacing.popoverWidth)
        .background(SigTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SigRadius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: SigRadius.panel)
                .stroke(SigTheme.divider, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Sig")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SigTheme.accent)
            if let dir = directionLabel {
                Text(dir)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SigTheme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(SigTheme.chipBg))
            }
            Spacer()
            ResultIconButton(
                systemName: "xmark",
                tint: SigTheme.textMuted,
                help: "Close",
                action: onClose
            )
        }
    }

    private var originalRow: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(original)
                .font(.system(size: 12.5))
                .foregroundColor(SigTheme.textMuted)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.tail)
            let isPlayingOriginal = viewModel.isSpeaking && viewModel.currentSpeakingText == original
            ResultIconButton(
                systemName: isPlayingOriginal ? "speaker.wave.3.fill" : "speaker.wave.2",
                tint: isPlayingOriginal ? SigTheme.accent : SigTheme.textMuted,
                help: isPlayingOriginal ? "Stop" : "Speak original",
                action: {
                    viewModel.speak(text: original, voiceCode: Self.voiceCode(for: sourceLanguage))
                }
            )
        }
    }

    private var translationCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(translated)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SigTheme.textPrimary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            VStack(spacing: 3) {
                let isPlayingTranslation = viewModel.isSpeaking && viewModel.currentSpeakingText == translated
                ResultIconButton(
                    systemName: isPlayingTranslation ? "speaker.wave.3.fill" : "speaker.wave.2",
                    tint: isPlayingTranslation ? SigTheme.accent : SigTheme.textMuted,
                    help: isPlayingTranslation ? "Stop" : "Speak translation",
                    action: {
                        viewModel.speak(text: translated, voiceCode: Self.voiceCode(for: targetLanguage))
                    }
                )
                ResultIconButton(
                    systemName: isCopied ? "checkmark" : "doc.on.doc",
                    tint: isCopied ? SigTheme.success : SigTheme.textMuted,
                    help: isCopied ? "Copied" : "Copy",
                    action: performCopy
                )
            }
        }
        .padding(12)
        .background(SigTheme.resultBg)
        .clipShape(RoundedRectangle(cornerRadius: SigRadius.input))
        .overlay(
            RoundedRectangle(cornerRadius: SigRadius.input)
                .stroke(SigTheme.resultBorder, lineWidth: 1.5)
        )
    }

    private func performCopy() {
        onCopy()
        isCopied = true
        // Cancel any in-flight reset so a quick second click doesn't have the
        // first task's 1.8s timer prematurely clear the second flash.
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            isCopied = false
        }
    }
}

// MARK: - Shared button

private struct ResultIconButton: View {
    let systemName: String
    let tint: Color
    let help: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 22, height: 22)
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

// MARK: - View model

@MainActor
class TranslationResultViewModel: ObservableObject {
    @Published var isSpeaking: Bool = false
    @Published var currentSpeakingText: String = ""

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechDelegate: TranslationSpeechDelegate?

    init() {
        speechDelegate = TranslationSpeechDelegate(viewModel: self)
        speechSynthesizer.delegate = speechDelegate
    }

    /// Caller chooses the voice (the autoTranslate detection gives us the
    /// correct language per side; no need for the old "Danish indicator words"
    /// heuristic that misfired on short English text containing 'i' / 'a').
    func speak(text: String, voiceCode: String) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            currentSpeakingText = ""
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        currentSpeakingText = text
        isSpeaking = true
        speechSynthesizer.speak(utterance)
    }

    fileprivate func speechDidFinish() {
        isSpeaking = false
        currentSpeakingText = ""
    }
}

final class TranslationSpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    weak var viewModel: TranslationResultViewModel?

    init(viewModel: TranslationResultViewModel) {
        self.viewModel = viewModel
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            viewModel?.speechDidFinish()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            viewModel?.speechDidFinish()
        }
    }
}

#Preview("DA → EN") {
    TranslationResultView(
        original: "Hej! Hvordan har du det?",
        translated: "Hello! How are you?",
        detectedSource: .danish,
        onCopy: {},
        onClose: {}
    )
}

#Preview("EN → DA") {
    TranslationResultView(
        original: "Where is the train station?",
        translated: "Hvor er togstationen?",
        detectedSource: .english,
        onCopy: {},
        onClose: {}
    )
}
