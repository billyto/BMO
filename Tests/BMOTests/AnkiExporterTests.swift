import XCTest
@testable import BMOLib

final class AnkiExporterTests: XCTestCase {

    private let headers = [
        "#separator:tab",
        "#html:true",
        "#notetype:Basic",
        "#deck:Dansk::fraSig",
        "#tags column:3",
        "#guid column:4",
    ]

    private func lines(_ file: String) -> [String] {
        file.components(separatedBy: "\n")
    }

    // MARK: - File layout

    func testEmptyExportIsHeadersOnly() {
        let file = AnkiExporter.makeFile(cards: [], deck: "Dansk::fraSig", includeIPA: true)

        XCTAssertEqual(file, headers.joined(separator: "\n") + "\n")
    }

    func testRowHasFrontBackTagAndGUID() {
        let card = AnkiCard(danish: "Hej", english: "Hello", sourceLang: .danish)

        let file = AnkiExporter.makeFile(cards: [card], deck: "Dansk::fraSig", includeIPA: true)

        XCTAssertEqual(Array(lines(file).prefix(headers.count)), headers)
        XCTAssertEqual(lines(file)[headers.count], "Hej\tHello\tfraSig\t\(card.id.uuidString)")
    }

    func testOneRowPerCardInOrder() {
        let cards = [
            AnkiCard(danish: "Hej", english: "Hello", sourceLang: .danish),
            AnkiCard(danish: "Tak", english: "Thanks", sourceLang: .english),
        ]

        let file = AnkiExporter.makeFile(cards: cards, deck: "Dansk::fraSig", includeIPA: false)
        let rows = lines(file).dropFirst(headers.count).filter { !$0.isEmpty }

        XCTAssertEqual(rows.map { $0.components(separatedBy: "\t")[0] }, ["Hej", "Tak"])
    }

    // MARK: - Deck name

    func testDeckNameIsTrimmed() {
        XCTAssertEqual(AnkiExporter.deckName("  Dansk::Ord \n"), "Dansk::Ord")
    }

    func testBlankDeckNameFallsBackToDefault() {
        XCTAssertEqual(AnkiExporter.deckName("   "), AnkiExporter.defaultDeckName)
        XCTAssertEqual(AnkiExporter.defaultDeckName, "Dansk::fraSig")
    }

    func testDeckNameFlattensTabsAndNewlines() {
        XCTAssertEqual(AnkiExporter.deckName("Dansk\tOrd\nNye"), "Dansk Ord Nye")
    }

    // MARK: - Escaping

    func testEscapesHTMLSpecialCharacters() {
        XCTAssertEqual(AnkiExporter.escape("a & b < c > d"), "a &amp; b &lt; c &gt; d")
    }

    func testEscapesQuotesAndHash() {
        XCTAssertEqual(AnkiExporter.escape("\"Hej\" #1"), "&quot;Hej&quot; &#35;1")
    }

    func testNewlinesBecomeBreaks() {
        XCTAssertEqual(AnkiExporter.escape("one\ntwo\r\nthree\rfour"), "one<br>two<br>three<br>four")
    }

    func testTabsBecomeSpaces() {
        XCTAssertEqual(AnkiExporter.escape("a\tb"), "a b")
    }

    func testEscapedFieldsKeepRowToFourColumns() {
        let card = AnkiCard(danish: "a\tb\nc", english: "d\te", sourceLang: .danish)

        let file = AnkiExporter.makeFile(cards: [card], deck: "Dansk::fraSig", includeIPA: false)

        XCTAssertEqual(lines(file)[headers.count].components(separatedBy: "\t").count, 4)
    }

    // MARK: - IPA

    func testIPAIsWrappedInSlashesUnderEnglish() {
        let card = AnkiCard(danish: "Hej", english: "Hello", ipa: "hˈɑj", sourceLang: .danish)

        XCTAssertEqual(AnkiExporter.back(for: card, includeIPA: true), "Hello<br><small>/hˈɑj/</small>")
    }

    func testIPAAlreadyInSlashesIsNotDoubleWrapped() {
        let card = AnkiCard(danish: "Hej", english: "Hello", ipa: "/hɛjˀ/", sourceLang: .danish)

        XCTAssertEqual(AnkiExporter.back(for: card, includeIPA: true), "Hello<br><small>/hɛjˀ/</small>")
    }

    func testIPAOmittedWhenDisabled() {
        let card = AnkiCard(danish: "Hej", english: "Hello", ipa: "hˈɑj", sourceLang: .danish)

        XCTAssertEqual(AnkiExporter.back(for: card, includeIPA: false), "Hello")
    }

    func testBlankIPAIsIgnored() {
        let card = AnkiCard(danish: "Hej", english: "Hello", ipa: "  ", sourceLang: .danish)

        XCTAssertEqual(AnkiExporter.back(for: card, includeIPA: true), "Hello")
    }

    // MARK: - File naming

    func testFileStemUsesDateAndTime() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 9, minute: 5)))

        XCTAssertEqual(AnkiExporter.fileStem(for: date, timeZone: utc), "Sig-Anki-2026-10-24-0905")
    }

    func testUniqueFileURLAddsSuffixWhenTaken() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AnkiExporterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let date = Date()

        let first = AnkiExporter.uniqueFileURL(in: directory, date: date)
        try "".write(to: first, atomically: true, encoding: .utf8)
        let second = AnkiExporter.uniqueFileURL(in: directory, date: date)

        XCTAssertEqual(first.lastPathComponent, "\(AnkiExporter.fileStem(for: date)).txt")
        XCTAssertEqual(second.lastPathComponent, "\(AnkiExporter.fileStem(for: date))-2.txt")
    }

    func testUniqueFileURLUsesChosenFormat() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AnkiExporterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let date = Date()

        let first = AnkiExporter.uniqueFileURL(in: directory, date: date, format: .tsv)
        try "".write(to: first, atomically: true, encoding: .utf8)
        let second = AnkiExporter.uniqueFileURL(in: directory, date: date, format: .tsv)

        XCTAssertEqual(first.pathExtension, "tsv")
        XCTAssertEqual(second.lastPathComponent, "\(AnkiExporter.fileStem(for: date))-2.tsv")
    }
}
