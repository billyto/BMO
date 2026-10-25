import XCTest
@testable import BMOLib

final class AnkiCardTests: XCTestCase {

    // MARK: - Building from a translation

    func testDanishSourceBecomesFront() throws {
        let card = try XCTUnwrap(AnkiCard(source: "Hej", translated: "Hello", from: .danish, to: .english))

        XCTAssertEqual(card.danish, "Hej")
        XCTAssertEqual(card.english, "Hello")
        XCTAssertEqual(card.sourceLang, .danish)
        XCTAssertNil(card.exportedAt)
    }

    func testEnglishSourceStillPutsDanishOnFront() throws {
        let card = try XCTUnwrap(AnkiCard(source: "Hello", translated: "Hej", from: .english, to: .danish))

        XCTAssertEqual(card.danish, "Hej")
        XCTAssertEqual(card.english, "Hello")
        XCTAssertEqual(card.sourceLang, .english)
    }

    func testTrimsSurroundingWhitespace() throws {
        let card = try XCTUnwrap(AnkiCard(source: "  Hej\n", translated: " Hello ", from: .danish, to: .english))

        XCTAssertEqual(card.danish, "Hej")
        XCTAssertEqual(card.english, "Hello")
    }

    func testBlankSideReturnsNil() {
        XCTAssertNil(AnkiCard(source: "   ", translated: "Hello", from: .danish, to: .english))
        XCTAssertNil(AnkiCard(source: "Hej", translated: "\n", from: .danish, to: .english))
    }

    func testCarriesIPA() throws {
        let card = try XCTUnwrap(AnkiCard(source: "Hej", translated: "Hello", from: .danish, to: .english, ipa: "hˈɑj"))

        XCTAssertEqual(card.ipa, "hˈɑj")
    }

    // MARK: - Duplicate key

    func testKeyIgnoresCaseAndSurroundingWhitespace() {
        XCTAssertEqual(AnkiCard.key(for: "  Hej Verden\n"), "hej verden")
        XCTAssertEqual(AnkiCard.key(for: "HEJ"), AnkiCard.key(for: "hej"))
    }

    // MARK: - Persistence

    func testCodableRoundTrip() throws {
        var card = AnkiCard(danish: "Tak", english: "Thanks", ipa: "tˈɑɡ", sourceLang: .danish)
        card.exportedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let data = try JSONEncoder().encode([card])
        let decoded = try JSONDecoder().decode([AnkiCard].self, from: data)

        XCTAssertEqual(decoded, [card])
    }
}
