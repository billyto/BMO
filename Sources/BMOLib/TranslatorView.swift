import SwiftUI
import AVFoundation

struct TranslatorView: View {
    @StateObject private var viewModel: TranslatorViewModel

    init(translationService: TranslationService, ipaService: IPAService) {
        _viewModel = StateObject(wrappedValue: TranslatorViewModel(
            translationService: translationService,
            ipaService: ipaService
        ))
    }

    var body: some View {
        VStack(spacing: 10) {
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("Sig")
                    .font(.title)
                    .bold()
                Text("Min danske hjælper")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
            .padding(.top, 30)

            // Language direction indicator
            Button(action: viewModel.swapLanguages) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(viewModel.sourceLanguage == .danish ? "🇩🇰 Danish" : "🇬🇧 English")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .baselineOffset(1)
                    Text(viewModel.targetLanguage == .danish ? "🇩🇰 Danish" : "🇬🇧 English")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.borderless)
            .help("Swap languages")
            .frame(maxWidth: .infinity)
            .offset(y: 5)

            // Input field
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Spacer()
                    if viewModel.sourceLanguage == .danish && !viewModel.inputText.isEmpty {
                        Button(action: viewModel.speakInputDanish) {
                            Image(systemName: viewModel.isSpeakingInput ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                        .help("Speak input in Danish")
                    }
                }
                .frame(height: 0)
                .offset(y: -10)

                ZStack(alignment: .topLeading) {
                    // Placeholder text
                    if viewModel.inputText.isEmpty {
                        Text("Text to translate")
                            .font(.body)
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                    }

                    // Text editor
                    TextEditor(text: $viewModel.inputText)
                        .font(.body)
                        .frame(height: 50)
                        .scrollDisabled(true)
                        .scrollContentBackground(.hidden)
                        .opacity(viewModel.inputText.isEmpty ? 0.5 : 1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .tint(Color(NSColor.darkGray))

                    // Clear button (bottom-trailing)
                    if !viewModel.inputText.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: viewModel.clear) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray.opacity(0.7))
                                        .font(.body)
                                }
                                .buttonStyle(.borderless)
                                .help("Clear all (⌘K)")
                                .keyboardShortcut("k", modifiers: .command)
                                .padding(10)
//                                .padding(.trailing, 0)
//                                .padding(.bottom, 0)
                            }
                        }
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            // Translate button
            Button(action: {
                Task {
                    await viewModel.translate()
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "globe")
                    }
                    Text("Translate")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
            .keyboardShortcut(.return, modifiers: .command)

            // Result area
            VStack(alignment: .leading, spacing: 4) {
                if let error = viewModel.errorMessage {
                    Text("Error:")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.body)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                } else if !viewModel.translatedText.isEmpty {
                    HStack {
                        Text("Translation:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: viewModel.speakDanish) {
                            Image(systemName: viewModel.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                        .help("Speak Danish translation")
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(viewModel.translatedText)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)

                            if let ipa = viewModel.ipaPronunciation {
                                HStack(spacing: 4) {
                                    Text("IPA:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(ipa)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .textSelection(.enabled)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 100)
                } else {
                    Text("...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .frame(minHeight: 100)

            // Shutdown button
            HStack {
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Quit BMO")
            }
            .padding(.top, 4)
            .offset(x:2 , y: -28)
        }
        .padding()
        .frame(width: 380, height: 340)
    }
}

@MainActor
class TranslatorViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var translatedText: String = ""
    @Published var ipaPronunciation: String?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var sourceLanguage: Language = .danish
    @Published var targetLanguage: Language = .english
    @Published var isSpeaking: Bool = false
    @Published var isSpeakingInput: Bool = false

    private let translationService: TranslationService
    private let ipaService: IPAService
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechDelegate: SpeechDelegate?

    init(translationService: TranslationService, ipaService: IPAService) {
        self.translationService = translationService
        self.ipaService = ipaService
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

        // Clear IPA pronunciation when swapping
        ipaPronunciation = nil

        // Optionally swap the text too
        if !translatedText.isEmpty {
            let tempText = inputText
            inputText = translatedText
            translatedText = tempText
        }
    }

    func clear() {
        inputText = ""
        translatedText = ""
        errorMessage = nil

        // Stop any ongoing speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            isSpeakingInput = false
        }
    }

    func translate() async {
        guard !inputText.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        translatedText = ""
        ipaPronunciation = nil

        do {
            let result = try await translationService.translate(
                text: inputText,
                from: sourceLanguage,
                to: targetLanguage
            )
            translatedText = result

            // Fetch IPA pronunciation for the translated text
            if let ipa = try? await ipaService.fetchIPA(for: result, language: targetLanguage) {
                ipaPronunciation = ipa
            }
        } catch let error as TranslationError {
            errorMessage = errorMessage(for: error)
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }

        isLoading = false
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
        translationService: try! TranslationService(apiKey: "preview-key", networkClient: MockNetworkClient()),
        ipaService: IPAService()
    )
}

#Preview("With Input Text") {
    let service = try! TranslationService(apiKey: "preview-key", networkClient: MockNetworkClient())
    let ipaService = IPAService()
    TranslatorView(translationService: service, ipaService: ipaService)
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
