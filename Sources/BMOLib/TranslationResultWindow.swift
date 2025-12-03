import SwiftUI
import AppKit
import AVFoundation

@MainActor
class TranslationResultWindow: NSObject {
    private var window: NSWindow?
    private var autoCloseTimer: Timer?

    init(original: String, translated: String) {
        super.init()
        setupWindow(original: original, translated: translated)
    }

    private func setupWindow(original: String, translated: String) {
        // Create the SwiftUI view
        let contentView = TranslationResultView(
            original: original,
            translated: translated,
            onCopy: { [weak self] in
                self?.copyToClipboard(translated)
            },
            onClose: { [weak self] in
                self?.close()
            }
        )

        // Create the window
        let hostingController = NSHostingController(rootView: contentView)
        window = NSWindow(contentViewController: hostingController)

        window?.styleMask = [.borderless, .nonactivatingPanel]
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.level = .floating
        window?.hasShadow = true
        window?.isMovableByWindowBackground = true

        // Set window size
        window?.setContentSize(NSSize(width: 400, height: 200))

        // Position near mouse cursor
        if let mouseLocation = NSEvent.mouseLocation as NSPoint? {
            let screenFrame = NSScreen.main?.frame ?? .zero
            var windowOrigin = mouseLocation

            // Offset slightly from cursor
            windowOrigin.x += 20
            windowOrigin.y -= 40

            // Ensure window stays on screen
            if let windowSize = window?.frame.size {
                if windowOrigin.x + windowSize.width > screenFrame.maxX {
                    windowOrigin.x = screenFrame.maxX - windowSize.width - 10
                }
                if windowOrigin.y - windowSize.height < screenFrame.minY {
                    windowOrigin.y = screenFrame.minY + windowSize.height + 10
                }
            }

            window?.setFrameTopLeftPoint(windowOrigin)
        }

        // Setup auto-close timer based on settings
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

        // Show brief feedback
        NSSound.beep()
    }
}

struct TranslationResultView: View {
    let original: String
    let translated: String
    let onCopy: () -> Void
    let onClose: () -> Void

    @StateObject private var viewModel = TranslationResultViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with close button
            HStack {
                Text("Translation")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            Divider()

            // Original text (if not too long)
            if original.count <= 100 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Original:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            viewModel.speak(text: original)
                        }) {
                            Image(systemName: viewModel.isSpeaking && viewModel.currentSpeakingText == original ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                        .help("Speak original text")
                    }
                    Text(original)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            // Translated text
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Translation:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        viewModel.speak(text: translated)
                    }) {
                        Image(systemName: viewModel.isSpeaking && viewModel.currentSpeakingText == translated ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                    .help("Speak translation")
                }
                Text(translated)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .lineLimit(nil)
            }

            // Copy button
            HStack {
                Spacer()
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

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

    func speak(text: String) {
        // If already speaking, stop
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            currentSpeakingText = ""
            return
        }

        // Detect language and speak
        let utterance = AVSpeechUtterance(string: text)

        // Simple heuristic: if text contains Danish characters or common Danish words, use Danish voice
        let danishIndicators = ["æ", "ø", "å", "jeg", "det", "er", "og", "til", "med", "på"]
        let isDanish = danishIndicators.contains { text.lowercased().contains($0) }

        utterance.voice = AVSpeechSynthesisVoice(language: isDanish ? "da-DK" : "en-US")
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
}

#Preview {
    TranslationResultView(
        original: "Hej! Hvordan har du det?",
        translated: "Hello! How are you?",
        onCopy: {},
        onClose: {}
    )
    .frame(width: 400, height: 200)
}
