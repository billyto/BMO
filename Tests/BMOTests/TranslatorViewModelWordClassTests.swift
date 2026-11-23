import XCTest
@testable import BMOLib

@MainActor
final class TranslatorViewModelWordClassTests: XCTestCase {
    private var originalSetting = false

    override func setUp() async throws {
        originalSetting = AppSettings.shared.showWordClass
        AppSettings.shared.showWordClass = true
    }

    override func tearDown() async throws {
        AppSettings.shared.showWordClass = originalSetting
    }

    private func makeViewModel(_ item: HistoryItem) -> TranslatorViewModel {
        let viewModel = TranslatorViewModel(
            translationService: nil,
            phoneticsService: PhoneticsService(runner: MockPhoneticsRunner()),
            danishWordClassService: DanishWordClassService(lookup: MockDanishWordClassLookup())
        )
        viewModel.restore(from: item)
        return viewModel
    }

    /// Waits for the async Wiktionary (mock) lookup to land.
    private func waitForDanishClasses(_ viewModel: TranslatorViewModel) async {
        for _ in 0..<100 where viewModel.danishWordClasses.isEmpty {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testInputChipHidesOnceInputIsEdited() {
        let viewModel = makeViewModel(HistoryItem(
            sourceText: "run", translatedText: "løbe", sourceLang: .english, targetLang: .danish
        ))
        XCTAssertEqual(viewModel.inputWordClasses, [.verb])

        viewModel.setInput("house")  // edited, auto-translate off

        XCTAssertEqual(viewModel.inputWordClasses, [], "chip must not label the edited text")
        XCTAssertEqual(viewModel.wordClasses(for: .english), [.verb], "the pair itself is unchanged")
    }

    func testTurningSettingOffHidesLoadedDanishChip() async {
        let viewModel = makeViewModel(HistoryItem(
            sourceText: "tør", translatedText: "dry", sourceLang: .danish, targetLang: .english
        ))
        await waitForDanishClasses(viewModel)
        XCTAssertEqual(viewModel.wordClasses(for: .danish), [.adjective, .verb])

        AppSettings.shared.showWordClass = false

        XCTAssertEqual(viewModel.wordClasses(for: .danish), [])
        XCTAssertEqual(viewModel.inputWordClasses, [])
    }
}
