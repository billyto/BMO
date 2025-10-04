import SwiftUI

struct TranslatorView: View {
    @StateObject private var viewModel: TranslatorViewModel

    init(translationService: TranslationService) {
        _viewModel = StateObject(wrappedValue: TranslatorViewModel(translationService: translationService))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("BMO Translator")
                    .font(.headline)
                Spacer()
                Button(action: viewModel.swapLanguages) {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.plain)
                .help("Swap languages")
            }
            .padding(.bottom, 4)

            // Language direction indicator
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.sourceLanguage == .danish ? "🇩🇰 Danish" : "🇬🇧 English")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .baselineOffset(1)
                Text(viewModel.targetLanguage == .danish ? "🇩🇰 Danish" : "🇬🇧 English")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .offset(y: 20)

            // Input field
            VStack(alignment: .leading, spacing: 4) {
                Text("Text to translate:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $viewModel.inputText)
                    .font(.body)
                    .frame(height: 80)
                    .border(Color.gray.opacity(0.3), width: 1)
                    .cornerRadius(4)
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
                    Text("Translation:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ScrollView {
                        Text(viewModel.translatedText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .frame(maxHeight: 100)
                } else {
                    Text("Enter text above and click Translate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .frame(minHeight: 120)

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

@MainActor
class TranslatorViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var translatedText: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var sourceLanguage: Language = .danish
    @Published var targetLanguage: Language = .english

    private let translationService: TranslationService

    init(translationService: TranslationService) {
        self.translationService = translationService
    }

    func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp

        // Optionally swap the text too
        if !translatedText.isEmpty {
            let tempText = inputText
            inputText = translatedText
            translatedText = tempText
        }
    }

    func translate() async {
        guard !inputText.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        translatedText = ""

        do {
            let result = try await translationService.translate(
                text: inputText,
                from: sourceLanguage,
                to: targetLanguage
            )
            translatedText = result
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
}
