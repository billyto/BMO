import XCTest
@testable import BMOLib

final class DankiExporterTests: XCTestCase {

    private let exportedAt = Date(timeIntervalSince1970: 1_795_000_000)
    private let createdAt = Date(timeIntervalSince1970: 1_794_000_000)

    private func card(
        danish: String = "interessant",
        english: String = "interesting",
        ipa: String? = nil,
        danishWordClasses: [WordClass]? = nil,
        sourceLang: Language = .english,
        updatedAt: Date? = nil,
        exportedAt: Date? = nil
    ) -> AnkiCard {
        AnkiCard(
            danish: danish,
            english: english,
            ipa: ipa,
            danishWordClasses: danishWordClasses,
            sourceLang: sourceLang,
            createdAt: createdAt,
            updatedAt: updatedAt,
            exportedAt: exportedAt
        )
    }

    /// The encoded file parsed back as plain JSON, to check the contract's key names.
    private func json(_ file: DankiExporter.File) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: DankiExporter.encode(file))
        return try XCTUnwrap(object as? [String: Any])
    }

    // MARK: - File

    func testTopLevelFields() throws {
        let file = DankiExporter.makeFile(cards: [], deck: "Dansk::fraSig", appVersion: "1.11", exportedAt: exportedAt)
        let root = try json(file)

        XCTAssertEqual(Set(root.keys), ["schemaVersion", "exportedAt", "source", "decks", "cards"])
        XCTAssertEqual(root["schemaVersion"] as? Int, 1)
        XCTAssertEqual(root["exportedAt"] as? String, "2026-11-18T11:06:40Z")
        XCTAssertEqual(root["source"] as? [String: String], ["app": "Sig", "version": "1.11"])
    }

    func testMissingAppVersionIsOmitted() throws {
        let file = DankiExporter.makeFile(cards: [], deck: "Dansk::fraSig", appVersion: nil, exportedAt: exportedAt)

        XCTAssertEqual(try json(file)["source"] as? [String: String], ["app": "Sig"])
    }

    func testOneDeckNamedFromSettings() {
        let file = DankiExporter.makeFile(cards: [], deck: "  Dansk::Ord ", appVersion: nil, exportedAt: exportedAt)

        XCTAssertEqual(file.decks.map(\.name), ["Dansk::Ord"])
        XCTAssertEqual(file.decks.first?.updatedAt, exportedAt)
    }

    func testBlankDeckNameFallsBackToDefault() {
        let file = DankiExporter.makeFile(cards: [], deck: " ", appVersion: nil, exportedAt: exportedAt)

        XCTAssertEqual(file.decks.map(\.name), [AnkiExporter.defaultDeckName])
    }

    func testIncludesPendingAndExportedCards() {
        let cards = [card(danish: "Hej"), card(danish: "Tak", exportedAt: exportedAt)]

        let file = DankiExporter.makeFile(cards: cards, deck: "Dansk::fraSig", appVersion: nil, exportedAt: exportedAt)

        XCTAssertEqual(file.cards.map(\.danish), ["Hej", "Tak"])
    }

    // MARK: - Deck id

    func testDeckIDIsStableForAName() {
        XCTAssertEqual(DankiExporter.deckID(for: "Dansk::fraSig"), DankiExporter.deckID(for: "Dansk::fraSig"))
        XCTAssertNotEqual(DankiExporter.deckID(for: "Dansk::fraSig"), DankiExporter.deckID(for: "Dansk::Ord"))
    }

    func testDeckIDIsAVersion5UUID() {
        let id = DankiExporter.deckID(for: "Dansk::fraSig").uuidString

        XCTAssertEqual(Array(id)[14], "5")
        XCTAssertTrue("89AB".contains(Array(id)[19]))
    }

    func testNameBasedUUIDMatchesRFC4122Vector() {
        // Python: uuid.uuid5(uuid.NAMESPACE_DNS, "python.org")
        let dns = UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")!

        XCTAssertEqual(
            DankiExporter.nameBasedUUID(namespace: dns, name: "python.org").uuidString,
            "886313E1-3B8A-5372-9B90-0C9AEE199E5D"
        )
    }

    // MARK: - Card

    func testCardFields() throws {
        let source = card(ipa: "entʁɛˈsanˀt", danishWordClasses: [.adjective])
        let file = DankiExporter.makeFile(cards: [source], deck: "Dansk::fraSig", appVersion: nil, exportedAt: exportedAt)
        let cards = try XCTUnwrap(try json(file)["cards"] as? [[String: Any]])
        let row = try XCTUnwrap(cards.first)

        XCTAssertEqual(row["id"] as? String, source.id.uuidString)
        XCTAssertEqual(row["deckId"] as? String, file.decks.first?.id.uuidString)
        XCTAssertEqual(row["danish"] as? String, "interessant")
        XCTAssertEqual(row["translations"] as? [String: String], ["en": "interesting"])
        XCTAssertEqual(row["ipa"] as? String, "/entʁɛˈsanˀt/")
        XCTAssertEqual(row["wordClasses"] as? [String], ["adjective"])
        XCTAssertEqual(row["tags"] as? [String], ["fraSig"])
        XCTAssertEqual(row["sourceLanguage"] as? String, "en")
        XCTAssertEqual(row["createdAt"] as? String, "2026-11-06T21:20:00Z")
        XCTAssertEqual(row["updatedAt"] as? String, "2026-11-06T21:20:00Z")
        XCTAssertEqual(row["deleted"] as? Bool, false)
    }

    func testUpdatedAtFollowsLaterFillIns() throws {
        let filledIn = Date(timeIntervalSince1970: 1_794_500_000)
        let file = DankiExporter.makeFile(
            cards: [card(updatedAt: filledIn)], deck: "Dansk::fraSig", appVersion: nil, exportedAt: exportedAt
        )
        let row = try XCTUnwrap((try json(file)["cards"] as? [[String: Any]])?.first)

        XCTAssertEqual(row["createdAt"] as? String, "2026-11-06T21:20:00Z")
        XCTAssertEqual(row["updatedAt"] as? String, "2026-11-12T16:13:20Z")
    }

    func testMissingIPAIsOmitted() throws {
        let file = DankiExporter.makeFile(cards: [card()], deck: "Dansk::fraSig", appVersion: nil, exportedAt: exportedAt)
        let row = try XCTUnwrap((try json(file)["cards"] as? [[String: Any]])?.first)

        XCTAssertNil(row["ipa"])
    }

    func testDanishSourceLanguageCode() {
        let exported = DankiExporter.card(from: card(sourceLang: .danish), deckID: UUID())

        XCTAssertEqual(exported.sourceLanguage, "da")
    }

    func testIPAIsTrimmedAndWrapped() {
        XCTAssertEqual(DankiExporter.ipa(" hɛjˀ \n"), "/hɛjˀ/")
        XCTAssertEqual(DankiExporter.ipa("/hɛjˀ/"), "/hɛjˀ/")
        XCTAssertNil(DankiExporter.ipa("  "))
        XCTAssertNil(DankiExporter.ipa(nil))
    }

    func testDanishWordClassesWin() {
        let exported = DankiExporter.card(from: card(danish: "tør", english: "dry", danishWordClasses: [.adjective, .verb]), deckID: UUID())

        XCTAssertEqual(exported.wordClasses, [.adjective, .verb])
    }

    func testFallsBackToEnglishWordClass() {
        let exported = DankiExporter.card(from: card(danish: "bil", english: "car"), deckID: UUID())

        XCTAssertEqual(exported.wordClasses, [.noun])
    }

    func testSentenceHasNoWordClasses() {
        let exported = DankiExporter.card(
            from: card(danish: "Jeg kan godt lide kaffe", english: "I really like coffee a lot"),
            deckID: UUID()
        )

        XCTAssertEqual(exported.wordClasses, [])
    }

    // MARK: - Location

    func testWritesToICloudDriveDankiFolderWhenPresent() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let iCloudDrive = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        try FileManager.default.createDirectory(at: iCloudDrive, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let directory = try DankiExporter.exportDirectory(home: home, iCloudSignedIn: true)

        XCTAssertEqual(directory.standardizedFileURL, iCloudDrive.appendingPathComponent("Danki").standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }

    func testFallsBackToDownloadsWithoutICloudDrive() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let directory = try DankiExporter.exportDirectory(home: home, iCloudSignedIn: true)

        XCTAssertEqual(directory.lastPathComponent, "Downloads")
    }

    /// The folder outlives signing out of iCloud; a file there would never sync.
    func testFallsBackToDownloadsWhenSignedOutDespiteLeftoverFolder() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let iCloudDrive = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        try FileManager.default.createDirectory(at: iCloudDrive, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let directory = try DankiExporter.exportDirectory(home: home, iCloudSignedIn: false)

        XCTAssertEqual(directory.lastPathComponent, "Downloads")
        XCTAssertFalse(FileManager.default.fileExists(atPath: iCloudDrive.appendingPathComponent("Danki").path))
    }
}
