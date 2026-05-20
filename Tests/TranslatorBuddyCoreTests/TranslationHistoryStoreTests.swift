import Foundation
import XCTest
@testable import TranslatorBuddyCore

final class TranslationHistoryStoreTests: XCTestCase {
    func testRecordsPersistLocally() {
        let defaults = MemoryDefaults()
        let store = TranslationHistoryStore(defaults: defaults)
        let record = SavedTranslationRecord(
            id: UUID(),
            sourceText: "hola",
            sourceLanguageIdentifier: "es",
            outputs: [SavedTranslationOutput(target: .french, text: "bonjour")]
        )

        store.saveRecords([record])

        XCTAssertEqual(store.loadRecords(), [record])
    }

    func testUpsertMovesRecordToFront() {
        let store = TranslationHistoryStore(defaults: MemoryDefaults())
        let id = UUID()
        let old = SavedTranslationRecord(
            id: id,
            sourceText: "hola",
            sourceLanguageIdentifier: "es",
            outputs: [SavedTranslationOutput(target: .french, text: "bonjour")]
        )
        let updated = SavedTranslationRecord(
            id: id,
            sourceText: "hola",
            sourceLanguageIdentifier: "es",
            outputs: [
                SavedTranslationOutput(target: .french, text: "bonjour"),
                SavedTranslationOutput(target: .english, text: "hello")
            ]
        )

        XCTAssertEqual(store.upsert(updated, into: [old]), [updated])
    }

    func testClearRemovesSavedRecords() {
        let defaults = MemoryDefaults()
        let store = TranslationHistoryStore(defaults: defaults)
        let record = SavedTranslationRecord(
            id: UUID(),
            sourceText: "hola",
            sourceLanguageIdentifier: "es",
            outputs: [SavedTranslationOutput(target: .english, text: "hello")]
        )
        store.saveRecords([record])

        store.clear()

        XCTAssertTrue(store.loadRecords().isEmpty)
    }
}
