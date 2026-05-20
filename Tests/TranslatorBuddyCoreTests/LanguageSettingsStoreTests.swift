import Foundation
import XCTest
@testable import TranslatorBuddyCore

final class LanguageSettingsStoreTests: XCTestCase {
    func testDefaultsAreFrenchAndEnglish() {
        let store = LanguageSettingsStore(defaults: MemoryDefaults())

        XCTAssertEqual(store.loadTargets(), [.french, .english])
    }

    func testAddedLanguagesPersist() throws {
        let defaults = MemoryDefaults()
        let store = LanguageSettingsStore(defaults: defaults)

        let targets = try store.add(.german, to: store.loadTargets())
        store.saveTargets(targets)

        XCTAssertEqual(store.loadTargets(), [.french, .english, .german])
    }

    func testDuplicateTargetsAreRejected() {
        let store = LanguageSettingsStore(defaults: MemoryDefaults())

        XCTAssertThrowsError(try store.add(.french, to: [.french, .english])) { error in
            XCTAssertEqual(error as? LanguageSettingsError, .duplicateTarget)
        }
    }

    func testCannotRemoveLastTarget() {
        let store = LanguageSettingsStore(defaults: MemoryDefaults())

        XCTAssertThrowsError(try store.remove(.french, from: [.french])) { error in
            XCTAssertEqual(error as? LanguageSettingsError, .cannotRemoveLastTarget)
        }
    }

    func testCanSetShownLanguages() throws {
        let store = LanguageSettingsStore(defaults: MemoryDefaults())

        let targets = try store.setTargets([.french, .english, .french, .german])

        XCTAssertEqual(targets, [.french, .english, .german])
    }

    func testCannotSetNoShownLanguages() {
        let store = LanguageSettingsStore(defaults: MemoryDefaults())

        XCTAssertThrowsError(try store.setTargets([])) { error in
            XCTAssertEqual(error as? LanguageSettingsError, .cannotRemoveLastTarget)
        }
    }
}

final class MemoryDefaults: KeyValueStore, @unchecked Sendable {
    private var values: [String: Data] = [:]

    func data(forKey defaultName: String) -> Data? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value as? Data
    }
}
