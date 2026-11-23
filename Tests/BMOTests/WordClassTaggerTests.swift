import XCTest
@testable import BMOLib

final class WordClassTaggerTests: XCTestCase {

    // MARK: - English tagging

    func testSingleWords() {
        XCTAssertEqual(WordClassTagger.wordClass(english: "house"), .noun)
        XCTAssertEqual(WordClassTagger.wordClass(english: "run"), .verb)
        XCTAssertEqual(WordClassTagger.wordClass(english: "beautiful"), .adjective)
        XCTAssertEqual(WordClassTagger.wordClass(english: "quickly"), .adverb)
    }

    func testFunctionWordsDontDecideShortPhrases() {
        XCTAssertEqual(WordClassTagger.wordClass(english: "to run"), .verb)
        XCTAssertEqual(WordClassTagger.wordClass(english: "the house"), .noun)
    }

    func testMixedClassesGiveNoHint() {
        XCTAssertNil(WordClassTagger.wordClass(english: "big house"))
    }

    func testSentencesGiveNoHint() {
        XCTAssertNil(WordClassTagger.wordClass(english: "I run every morning"))
    }

    func testBlankGivesNoHint() {
        XCTAssertNil(WordClassTagger.wordClass(english: "  \n"))
    }

    // MARK: - Picking the English side

    func testTagsTranslationWhenTranslatingFromDanish() {
        XCTAssertEqual(
            WordClassTagger.wordClass(source: "løbe", translated: "run", from: .danish, to: .english),
            .verb
        )
    }

    func testTagsSourceWhenTranslatingFromEnglish() {
        XCTAssertEqual(
            WordClassTagger.wordClass(source: "house", translated: "hus", from: .english, to: .danish),
            .noun
        )
    }

    // MARK: - Anki tag

    func testExportAddsWordClassTagWhenEnabled() {
        let card = AnkiCard(danish: "løbe", english: "run", sourceLang: .danish)

        XCTAssertEqual(AnkiExporter.tags(for: card, includeWordClass: true), "fraSig verb")
        XCTAssertEqual(AnkiExporter.tags(for: card, includeWordClass: false), "fraSig")
    }

    func testExportPrefersSavedDanishClasses() {
        let card = AnkiCard(danish: "tør", english: "dry", danishWordClasses: [.adjective, .verb], sourceLang: .danish)

        XCTAssertEqual(AnkiExporter.tags(for: card, includeWordClass: true), "fraSig adjective verb")
        XCTAssertEqual(AnkiExporter.tags(for: card, includeWordClass: false), "fraSig")
    }

    func testExportFileUsesEachCardsOwnClasses() {
        let tør = AnkiCard(danish: "tør", english: "dry", danishWordClasses: [.adjective, .verb], sourceLang: .danish)
        let løbe = AnkiCard(danish: "løbe", english: "run", sourceLang: .danish)

        let file = AnkiExporter.makeFile(cards: [tør, løbe], deck: "Dansk::fraSig", includeIPA: false, includeWordClass: true)
        let tagColumns = file.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("#") && !$0.isEmpty }
            .map { $0.components(separatedBy: "\t")[2] }

        // løbe has nothing saved, so it falls back to the English class.
        XCTAssertEqual(tagColumns, ["fraSig adjective verb", "fraSig verb"])
    }

    func testExportKeepsPlainTagWhenNoClass() {
        let card = AnkiCard(danish: "Jeg løber hver morgen", english: "I run every morning", sourceLang: .danish)

        XCTAssertEqual(AnkiExporter.tags(for: card, includeWordClass: true), "fraSig")
    }
}
