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

    // MARK: - Telling failures apart

    func testLookupDistinguishesFailureFromNoEntry() async {
        let service = DanishWordClassService(lookup: StubLookup(["hus": [.noun]]))
        let found = await service.lookup("hus")
        let missing = await service.lookup("xyzzy")
        let phrase = await service.lookup("stort hus")
        XCTAssertEqual(found, .found([.noun]))
        XCTAssertEqual(missing, .notFound)
        XCTAssertEqual(phrase, .notApplicable)

        let down = DanishWordClassService(lookup: StubLookup([:], failAll: true))
        let failed = await down.lookup("hus")
        XCTAssertEqual(failed, .failed)
    }

    // MARK: - Export when Wiktionary is down

    @MainActor
    func testExportStopsCallingWiktionaryAfterFirstFailure() async {
        let lookup = StubLookup([:], failAll: true)
        let exporter = AnkiExportModel(danishWordClassService: DanishWordClassService(lookup: lookup))
        var cards = ["tør", "hus", "Jeg løber hver morgen", "at løbe"].map {
            AnkiCard(danish: $0, english: "x", sourceLang: .danish)
        }

        let unavailable = await exporter.fillDanishWordClasses(in: &cards) { _, _ in
            XCTFail("nothing should be saved when lookups fail")
        }

        let calls = await lookup.calls
        XCTAssertEqual(calls, 1, "only the first card should wait on Wiktionary")
        // tør (failed) + hus + at løbe (skipped); the sentence was never eligible.
        XCTAssertEqual(unavailable, 3)
        XCTAssertTrue(cards.allSatisfy { $0.danishWordClasses == nil })
    }

    @MainActor
    func testExportSavesAnswersAndSkipsCardsThatHaveThem() async {
        let lookup = StubLookup(["tør": [.adjective, .verb]])
        let exporter = AnkiExportModel(danishWordClassService: DanishWordClassService(lookup: lookup))
        var cards = [
            AnkiCard(danish: "tør", english: "dry", sourceLang: .danish),
            AnkiCard(danish: "hus", english: "house", danishWordClasses: [.noun], sourceLang: .danish),
        ]
        var saved: [UUID: [WordClass]] = [:]

        let unavailable = await exporter.fillDanishWordClasses(in: &cards) { saved[$1] = $0 }

        let calls = await lookup.calls
        XCTAssertEqual(calls, 1, "hus already had classes saved")
        XCTAssertEqual(unavailable, 0)
        XCTAssertEqual(cards[0].danishWordClasses, [.adjective, .verb])
        XCTAssertEqual(saved, [cards[0].id: [.adjective, .verb]])
    }

    @MainActor
    func testUnavailableNotice() {
        XCTAssertNil(AnkiExportModel.unavailableNotice(count: 0))
        XCTAssertEqual(
            AnkiExportModel.unavailableNotice(count: 1),
            "Wiktionary didn't respond, so 1 card got the English word type instead. "
                + "To try adding the Danish types, use Export again on those cards and re-import the file."
        )
        XCTAssertTrue(AnkiExportModel.unavailableNotice(count: 3)?.contains("3 cards") == true)
    }
}

private actor StubLookup: DanishWordClassLookup {
    private let answers: [String: [WordClass]]
    private var failNext: Bool
    private let failAll: Bool
    private(set) var calls = 0

    init(_ answers: [String: [WordClass]], failFirst: Bool = false, failAll: Bool = false) {
        self.answers = answers
        self.failNext = failFirst
        self.failAll = failAll
    }

    func wordClasses(for word: String) async throws -> [WordClass] {
        calls += 1
        if failAll { throw URLError(.timedOut) }
        if failNext {
            failNext = false
            throw URLError(.notConnectedToInternet)
        }
        return answers[word] ?? []
    }
}
