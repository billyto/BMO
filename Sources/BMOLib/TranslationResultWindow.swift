import SwiftUI
import AppKit

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

        // Setup auto-close timer (10 seconds)
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.close()
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

    @State private var isHovering = false

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
                    Text("Original:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(original)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            // Translated text
            VStack(alignment: .leading, spacing: 4) {
                Text("Translation:")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

#Preview {
    TranslationResultView(
        original: "Hej! Hvordan har du det?",
        translated: "Hello! How are you?",
        onCopy: {},
        onClose: {}
    )
    .frame(width: 400, height: 200)
}
