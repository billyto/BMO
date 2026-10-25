import XCTest
@testable import BMOLib

@MainActor
final class TranslatorViewModelAnkiTests: XCTestCase {

    private func makeViewModel() -> TranslatorViewModel {
        let viewModel = TranslatorViewModel(translationService: nil)
        viewModel.restore(from: HistoryItem(
            sourceText: "Hej",
            translatedText: "Hello",
            sourceLang: .danish,
            targetLang: .english
        ))
        return viewModel
    }

    func testSwapKeepsTranslationPairAfterInputEdit() {
        let viewModel = makeViewModel()
        viewModel.setInput("Tak")  // edited after the translation landed

        viewModel.swapLanguages()

        XCTAssertEqual(viewModel.inputText, "Hello")
        XCTAssertEqual(viewModel.translatedText, "Hej")
        XCTAssertEqual(viewModel.ankiCandidate?.danish, "Hej")
        XCTAssertEqual(viewModel.ankiCandidate?.english, "Hello")
    }

    func testSwapDoesNotTruncateBookmarkedText() {
        let longEnglish = String(repeating: "a", count: TranslatorViewModel.inputCharLimit + 50)
        let viewModel = TranslatorViewModel(translationService: nil)
        viewModel.restore(from: HistoryItem(
            sourceText: "Hej",
            translatedText: longEnglish,
            sourceLang: .danish,
            targetLang: .english
        ))

        viewModel.swapLanguages()

        XCTAssertEqual(viewModel.inputText.count, TranslatorViewModel.inputCharLimit)
        XCTAssertEqual(viewModel.ankiCandidate?.english, longEnglish)
        XCTAssertEqual(viewModel.ankiCandidate?.danish, "Hej")
    }
}
