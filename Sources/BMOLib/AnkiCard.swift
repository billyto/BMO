import Foundation

/// A translation bookmarked for export to Anki. Always Danish-front /
/// English-back regardless of which direction it was translated in — the app
/// is a Danish-learning aid, and Anki checks duplicates on the first field,
/// so Danish has to be first.
struct AnkiCard: Codable, Identifiable, Equatable {
    /// Doubles as the Anki note GUID in the export file, so re-importing the
    /// same card updates the existing note instead of adding a duplicate.
    let id: UUID
    let danish: String
    let english: String
    /// Saved at mark time when the surface already has it; otherwise filled in
    /// at export time (cards marked from History never have one).
    var ipa: String?
    /// The language the user translated from. Context only — doesn't affect
    /// the card layout.
    let sourceLang: Language
    let createdAt: Date
    /// Nil while pending; set once the card has been written to an export file.
    var exportedAt: Date?

    var isExported: Bool { exportedAt != nil }

    /// Duplicate-detection key — see `key(for:)`.
    var key: String { Self.key(for: danish) }

    init(
        id: UUID = UUID(),
        danish: String,
        english: String,
        ipa: String? = nil,
        sourceLang: Language,
        createdAt: Date = Date(),
        exportedAt: Date? = nil
    ) {
        self.id = id
        self.danish = danish
        self.english = english
        self.ipa = ipa
        self.sourceLang = sourceLang
        self.createdAt = createdAt
        self.exportedAt = exportedAt
    }

    /// Builds a card from a translation in either direction. Nil when neither
    /// side is Danish (e.g. a Services translation from a non-DA/EN source)
    /// or when either side is blank.
    init?(
        source: String,
        translated: String,
        from: Language,
        to: Language,
        ipa: String? = nil,
        createdAt: Date = Date()
    ) {
        guard let danish = danishText(source: source, translated: translated, from: from, to: to) else {
            return nil
        }
        let english = from == .danish ? translated : source
        let trimmedDanish = danish.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnglish = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDanish.isEmpty, !trimmedEnglish.isEmpty else { return nil }

        self.init(
            danish: trimmedDanish,
            english: trimmedEnglish,
            ipa: ipa,
            sourceLang: from,
            createdAt: createdAt
        )
    }

    /// One card per Danish phrase: "Hej " marked from the popover and "hej"
    /// marked from History count as the same card.
    static func key(for danish: String) -> String {
        danish.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// The user's bookmarked cards, newest first. A plain value type so the
/// mark/export rules are unit-testable without the AppSettings singleton
/// (which reads and writes UserDefaults.standard).
struct AnkiCardList: Equatable {
    enum MarkState: Equatable {
        case unmarked
        case pending
        case exported
    }

    private(set) var cards: [AnkiCard]

    init(cards: [AnkiCard] = []) {
        self.cards = cards
    }

    var isEmpty: Bool { cards.isEmpty }
    var pending: [AnkiCard] { cards.filter { !$0.isExported } }
    var exported: [AnkiCard] { cards.filter(\.isExported) }

    func card(forDanish danish: String) -> AnkiCard? {
        let key = AnkiCard.key(for: danish)
        return cards.first { $0.key == key }
    }

    func markState(forDanish danish: String) -> MarkState {
        guard let card = self.card(forDanish: danish) else { return .unmarked }
        return card.isExported ? .exported : .pending
    }

    /// Adds `card` if its Danish phrase isn't in the list yet; removes the
    /// match if it's still pending. An exported match is left alone —
    /// un-marking and re-marking it would mint a new GUID, and the next export
    /// would create a duplicate note in Anki. Exported cards can still be
    /// removed from the list view via `delete(id:)`.
    mutating func toggle(_ card: AnkiCard) {
        guard let existing = self.card(forDanish: card.danish) else {
            cards.insert(card, at: 0)
            return
        }
        guard !existing.isExported else { return }
        cards.removeAll { $0.id == existing.id }
    }

    mutating func delete(id: UUID) {
        cards.removeAll { $0.id == id }
    }

    mutating func markExported(ids: Set<UUID>, at date: Date = Date()) {
        for index in cards.indices where ids.contains(cards[index].id) {
            cards[index].exportedAt = date
        }
    }

    mutating func clearExported() {
        cards.removeAll(where: \.isExported)
    }

    /// Used by export to save IPA looked up at export time back onto the card.
    mutating func setIPA(_ ipa: String, forCardID id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].ipa = ipa
    }
}
