import XCTest
@testable import BMOLib

final class DanishWordClassTests: XCTestCase {

    // MARK: - Wiktionary response parsing

    func testParsesDanishEntriesInOrderWithoutDuplicates() {
        // Shape of the real response for "tør" (definitions trimmed).
        let json = """
        {"da": [
            {"partOfSpeech": "Adjective", "language": "Danish", "definitions": []},
            {"partOfSpeech": "Verb", "language": "Danish", "definitions": []},
            {"partOfSpeech": "Verb", "language": "Danish", "definitions": []}
         ],
         "other": [{"partOfSpeech": "Noun", "language": "Norwegian", "definitions": []}]}
        """
        XCTAssertEqual(WiktionaryWordClassLookup.parse(Data(json.utf8)), [.adjective, .verb])
    }

    func testIgnoresOtherLanguagesAndUnknownParts() {
        let json = """
        {"other": [{"partOfSpeech": "Noun", "language": "Swedish", "definitions": []}],
         "da": [{"partOfSpeech": "Suffix", "language": "Danish", "definitions": []}]}
        """
        XCTAssertEqual(WiktionaryWordClassLookup.parse(Data(json.utf8)), [])
    }

    func testMalformedResponseGivesNothing() {
        XCTAssertEqual(WiktionaryWordClassLookup.parse(Data("not json".utf8)), [])
    }

    // MARK: - What gets looked up

    func testQueryForSingleWordAndPrefixedForms() {
        XCTAssertEqual(DanishWordClassService.query(for: " tør "), .init(word: "tør", implied: nil))
        XCTAssertEqual(DanishWordClassService.query(for: "Hus!"), .init(word: "Hus", implied: nil))
        XCTAssertEqual(DanishWordClassService.query(for: "at løbe"), .init(word: "løbe", implied: .verb))
        XCTAssertEqual(DanishWordClassService.query(for: "et løb"), .init(word: "løb", implied: .noun))
        XCTAssertNil(DanishWordClassService.query(for: "stort hus"))
        XCTAssertNil(DanishWordClassService.query(for: "Jeg løber hver morgen"))
        XCTAssertNil(DanishWordClassService.query(for: "   "))
    }

    // MARK: - Service

    func testListsEveryClassForABareWord() async {
        let service = DanishWordClassService(lookup: StubLookup(["løb": [.noun, .verb]]))
        let classes = await service.wordClasses(for: "løb")
        XCTAssertEqual(classes, [.noun, .verb])
    }

    func testPrefixNarrowsToItsClass() async {
        let service = DanishWordClassService(lookup: StubLookup(["løb": [.noun, .verb]]))
        let asNoun = await service.wordClasses(for: "et løb")
        let asVerb = await service.wordClasses(for: "at løb")
        XCTAssertEqual(asNoun, [.noun])
        XCTAssertEqual(asVerb, [.verb])
    }

    func testFallsBackToLowercaseForCapitalizedWord() async {
        let service = DanishWordClassService(lookup: StubLookup(["hus": [.noun]]))
        let classes = await service.wordClasses(for: "Hus")
        XCTAssertEqual(classes, [.noun])
    }

    func testCachesAnswers() async {
        let lookup = StubLookup(["hus": [.noun]])
        let service = DanishWordClassService(lookup: lookup)
        _ = await service.wordClasses(for: "hus")
        _ = await service.wordClasses(for: "hus")
        let calls = await lookup.calls
        XCTAssertEqual(calls, 1)
    }

    func testFailureIsNotCachedSoTheWordIsRetried() async {
        let lookup = StubLookup(["hus": [.noun]], failFirst: true)
        let service = DanishWordClassService(lookup: lookup)
        let offline = await service.wordClasses(for: "hus")
        let online = await service.wordClasses(for: "hus")
        XCTAssertEqual(offline, [])
        XCTAssertEqual(online, [.noun])
    }
}

private actor StubLookup: DanishWordClassLookup {
    private let answers: [String: [WordClass]]
    private var failNext: Bool
    private(set) var calls = 0

    init(_ answers: [String: [WordClass]], failFirst: Bool = false) {
        self.answers = answers
        self.failNext = failFirst
    }

    func wordClasses(for word: String) async throws -> [WordClass] {
        calls += 1
        if failNext {
            failNext = false
            throw URLError(.notConnectedToInternet)
        }
        return answers[word] ?? []
    }
}
