import SwiftUI
import AVFoundation

struct HistoryView: View {
    let onBack: () -> Void
    let onSelect: (HistoryItem) -> Void
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var speech = HistorySpeechModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewHeader(
                title: "History",
                onBack: onBack,
                trailing: settings.translationHistory.isEmpty ? nil : AnyView(
                    Button(action: {
                        speech.stop()
                        settings.clearHistory()
                    }) {
                        Text("Clear all")
                            .font(.system(size: 11))
                            .foregroundColor(SigTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all history")
                )
            )

            if settings.translationHistory.isEmpty {
                Spacer()
                Text("No history yet")
                    .font(.system(size: 12.5))
                    .foregroundColor(SigTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(settings.translationHistory) { item in
                            HistoryRow(
                                item: item,
                                speech: speech,
                                onSelect: { onSelect(item) },
                                onDelete: {
                                    if speech.speakingItemID == item.id { speech.stop() }
                                    settings.deleteHistoryItem(id: item.id)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(SigSpacing.panelPadding)
        .frame(width: SigSpacing.popoverWidth, height: 400)
        .background(SigTheme.surface)
        .onDisappear { speech.stop() }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    @ObservedObject var speech: HistorySpeechModel
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    private var directionLabel: String {
        "\(item.sourceLang.rawValue)→\(item.targetLang.rawValue)"
    }

    /// We only have a Danish TTS voice today; surface the speaker button on
    /// whichever side of the row is Danish (for DA↔EN entries that's always
    /// exactly one side).
    private var danishSide: (text: String, language: Language)? {
        if item.sourceLang == .danish { return (item.sourceText, .danish) }
        if item.targetLang == .danish { return (item.translatedText, .danish) }
        return nil
    }

    private var isSpeakingThisItem: Bool {
        speech.speakingItemID == item.id
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.sourceText)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(SigTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.translatedText)
                        .font(.system(size: 11.5))
                        .foregroundColor(SigTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Text(directionLabel)
                    .font(.system(size: 10))
                    .foregroundColor(SigTheme.textMuted)
                if let danish = danishSide {
                    Button(action: {
                        speech.toggle(text: danish.text, language: danish.language, itemID: item.id)
                    }) {
                        Image(systemName: isSpeakingThisItem ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.system(size: 11))
                            .foregroundColor(isSpeakingThisItem ? SigTheme.accent : SigTheme.textMuted)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isSpeakingThisItem ? "Stop" : "Speak Danish")
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(SigTheme.textMuted)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            // Keep the action group visible while playing so a "stop" button
            // doesn't disappear mid-playback when the user moves the pointer.
            .opacity(isHovered || isSpeakingThisItem ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: SigRadius.chip)
                .fill(isHovered ? SigTheme.chipBg : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Shared speech model

@MainActor
final class HistorySpeechModel: ObservableObject {
    /// The item currently being spoken (nil when idle). Rows observe this so
    /// the active row can flip its icon to the "speaking" variant.
    @Published private(set) var speakingItemID: UUID?

    private let synth = AVSpeechSynthesizer()
    private var delegate: HistorySpeechDelegate?

    init() {
        let d = HistorySpeechDelegate()
        d.model = self
        delegate = d
        synth.delegate = d
    }

    func toggle(text: String, language: Language, itemID: UUID) {
        // Tapping the row that's currently playing acts as a stop.
        if speakingItemID == itemID {
            stop()
            return
        }
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language == .danish ? "da-DK" : "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speakingItemID = itemID
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        speakingItemID = nil
    }

    fileprivate func finishedSpeaking() {
        speakingItemID = nil
    }
}

private final class HistorySpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    weak var model: HistorySpeechModel?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in model?.finishedSpeaking() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in model?.finishedSpeaking() }
    }
}

#Preview {
    HistoryView(onBack: {}, onSelect: { _ in })
}
