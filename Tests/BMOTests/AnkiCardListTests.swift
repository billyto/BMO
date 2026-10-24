import XCTest
@testable import BMOLib

final class AnkiCardListTests: XCTestCase {

    private func card(_ danish: String, _ english: String = "x") -> AnkiCard {
        AnkiCard(danish: danish, english: english, sourceLang: .danish)
    }

    // MARK: - Toggle

    func testToggleAddsNewestFirst() {
        var list = AnkiCardList()

        list.toggle(card("Hej"))
        list.toggle(card("Tak"))

        XCTAssertEqual(list.cards.map(\.danish), ["Tak", "Hej"])
    }

    func testToggleRemovesPendingMatch() {
        var list = AnkiCardList()
        list.toggle(card("Hej"))

        list.toggle(card("Hej"))

        XCTAssertTrue(list.isEmpty)
    }

    func testToggleMatchesAcrossCaseAndWhitespace() {
        var list = AnkiCardList()
        list.toggle(card("Hej verden"))

        // Same phrase bookmarked from another surface with different
        // casing/spacing.
        list.toggle(card(" hej Verden "))

        XCTAssertTrue(list.isEmpty)
    }

    func testToggleLeavesExportedMatchAlone() {
        let original = card("Hej")
        var list = AnkiCardList()
        list.toggle(original)
        list.markExported(ids: [original.id])

        list.toggle(card("Hej"))

        XCTAssertEqual(list.cards.count, 1)
        XCTAssertEqual(list.cards.first?.id, original.id)
        XCTAssertTrue(list.cards.first?.isExported == true)
    }

    // MARK: - Mark state

    func testMarkState() {
        let exported = card("Tak")
        var list = AnkiCardList()
        list.toggle(card("Hej"))
        list.toggle(exported)
        list.markExported(ids: [exported.id])

        XCTAssertEqual(list.markState(forDanish: "hej"), .pending)
        XCTAssertEqual(list.markState(forDanish: "Tak"), .exported)
        XCTAssertEqual(list.markState(forDanish: "Farvel"), .unmarked)
    }

    // MARK: - Export bookkeeping

    func testMarkExportedOnlyTouchesGivenIDs() {
        let first = card("Hej")
        let second = card("Tak")
        var list = AnkiCardList(cards: [first, second])
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        list.markExported(ids: [first.id], at: date)

        XCTAssertEqual(list.exported.map(\.id), [first.id])
        XCTAssertEqual(list.pending.map(\.id), [second.id])
        XCTAssertEqual(list.exported.first?.exportedAt, date)
    }

    func testMarkExportedIgnoresUnknownIDs() {
        var list = AnkiCardList(cards: [card("Hej")])

        list.markExported(ids: [UUID()])

        XCTAssertEqual(list.pending.count, 1)
    }

    func testClearExportedKeepsPending() {
        let exported = card("Hej")
        let pending = card("Tak")
        var list = AnkiCardList(cards: [exported, pending])
        list.markExported(ids: [exported.id])

        list.clearExported()

        XCTAssertEqual(list.cards.map(\.id), [pending.id])
    }

    func testMarkPendingKeepsIDForReExport() {
        let target = card("Hej")
        var list = AnkiCardList(cards: [target, card("Tak")])
        list.markExported(ids: [target.id])

        list.markPending(id: target.id)

        XCTAssertEqual(list.markState(forDanish: "Hej"), .pending)
        XCTAssertEqual(list.pending.map(\.id), list.cards.map(\.id))
        XCTAssertEqual(list.cards.first?.id, target.id)
    }

    func testDelete() {
        let doomed = card("Hej")
        let kept = card("Tak")
        var list = AnkiCardList(cards: [doomed, kept])

        list.delete(id: doomed.id)

        XCTAssertEqual(list.cards.map(\.id), [kept.id])
    }

    func testSetIPA() {
        let target = card("Hej")
        var list = AnkiCardList(cards: [target, card("Tak")])

        list.setIPA("hˈɑj", forCardID: target.id)

        XCTAssertEqual(list.cards.first?.ipa, "hˈɑj")
        XCTAssertNil(list.cards.last?.ipa)
    }
}
