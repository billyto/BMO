import CryptoKit
import Foundation

/// Builds the JSON file the Danki iPhone app imports. The format is a contract
/// owned by the Danki repo (`schema/danki-export.schema.json`,
/// `docs/card-format.md`); these types mirror its `DankiCore` models, but only
/// the fields Sig can fill.
///
/// Unlike the Anki export, this is a full snapshot: every bookmarked card,
/// pending or exported, written to one fixed file that's overwritten each
/// time. It never touches `exportedAt`, which tracks Anki only.
enum DankiExporter {
    /// The schema version this build writes. Bump only together with the Danki repo.
    static let schemaVersion = 1
    static let fileName = "Sig-Danki.json"

    struct File: Encodable, Equatable {
        var schemaVersion: Int
        var exportedAt: Date
        var source: Source
        var decks: [Deck]
        var cards: [Card]
    }

    struct Source: Encodable, Equatable {
        var app: String
        var version: String?
    }

    struct Deck: Encodable, Equatable {
        var id: UUID
        var name: String
        var updatedAt: Date
    }

    /// Optional fields are omitted from the JSON when nil.
    struct Card: Encodable, Equatable {
        var id: UUID
        var deckId: UUID
        var danish: String
        var translations: [String: String]
        var ipa: String?
        var wordClasses: [WordClass]
        var tags: [String]
        var sourceLanguage: String
        var createdAt: Date
        var updatedAt: Date
        var deleted: Bool
    }

    static func makeFile(cards: [AnkiCard], deck rawDeck: String, appVersion: String?, exportedAt: Date) -> File {
        let deckName = AnkiExporter.deckName(rawDeck)
        let deck = Deck(id: deckID(for: deckName), name: deckName, updatedAt: exportedAt)
        return File(
            schemaVersion: schemaVersion,
            exportedAt: exportedAt,
            source: Source(app: "Sig", version: appVersion),
            decks: [deck],
            cards: cards.map { card(from: $0, deckID: deck.id) }
        )
    }

    static func card(from card: AnkiCard, deckID: UUID) -> Card {
        Card(
            // The Anki note GUID, so the same card can live in Anki and Danki.
            id: card.id,
            deckId: deckID,
            danish: card.danish,
            translations: ["en": card.english],
            ipa: ipa(card.ipa),
            wordClasses: AnkiExporter.wordClasses(for: card),
            tags: [AnkiExporter.tag],
            sourceLanguage: card.sourceLang.dankiCode,
            createdAt: card.createdAt,
            // Bumped when IPA or word classes are filled in later, so Danki
            // can tell the card changed since the last file.
            updatedAt: card.lastModified,
            // Removed cards are gone from Sig, not kept as tombstones, so
            // every card in the file is live.
            deleted: false
        )
    }

    /// Same encoding as `DankiExportCoder.encode` in DankiCore: ISO 8601
    /// dates and sorted keys, so two exports of the same cards diff cleanly.
    static func encode(_ file: File) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(file)
    }

    /// Trimmed and wrapped in slashes like the Anki back side, or nil when blank.
    static func ipa(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)/"
    }

    /// Sig has one deck (named in Settings → Anki) and stores no id for it, so
    /// the id is derived from the name: the same name always gives the same
    /// id. Renaming the deck gives Danki a new deck.
    static func deckID(for name: String) -> UUID {
        nameBasedUUID(namespace: deckNamespace, name: name)
    }

    /// Fixed namespace for `deckID(for:)`. Never change it: every deck id depends on it.
    private static let deckNamespace = UUID(uuidString: "5D0A6B8E-2C1F-4E7A-9B3D-8F4C1A2E6D05")!

    /// RFC 4122 version 5 (SHA-1, name-based) UUID.
    static func nameBasedUUID(namespace: UUID, name: String) -> UUID {
        var data = withUnsafeBytes(of: namespace.uuid) { Data($0) }
        data.append(Data(name.utf8))
        var bytes = Array(Insecure.SHA1.hash(data: data).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// `~/Library/Mobile Documents/com~apple~CloudDocs/Danki` when iCloud Drive
    /// is on, so the phone can open the file from the Files app; otherwise
    /// Downloads. Sig isn't sandboxed, so it can write to iCloud Drive directly.
    ///
    /// The folder alone isn't proof: it stays behind after signing out of
    /// iCloud or turning iCloud Drive off, and a file written there then never
    /// syncs. So the signed-in check (`ubiquityIdentityToken`, which needs no
    /// entitlement) has to pass too.
    static func exportDirectory(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        iCloudSignedIn: Bool = FileManager.default.ubiquityIdentityToken != nil
    ) throws -> URL {
        let iCloudDrive = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        var isDirectory: ObjCBool = false
        if iCloudSignedIn,
           FileManager.default.fileExists(atPath: iCloudDrive.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            let folder = iCloudDrive.appendingPathComponent("Danki", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }
        return try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}

private extension Language {
    /// The lowercase codes Danki uses for translation keys and `sourceLanguage`.
    var dankiCode: String {
        switch self {
        case .danish: return "da"
        case .english: return "en"
        }
    }
}
