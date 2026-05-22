import Foundation
import XCTest
@testable import TranslatorBuddyCore

@MainActor
final class TranslatorViewModelTests: XCTestCase {
    func testBlankInputClearsResults() {
        let viewModel = makeViewModel()

        viewModel.setText("hola", for: .spanish)
        viewModel.flushDebounceForTesting()
        XCTAssertTrue(viewModel.results.allSatisfy { $0.status == .translating })

        viewModel.setText("   ", for: .spanish)

        XCTAssertTrue(viewModel.pendingRequests.isEmpty)
        XCTAssertEqual(viewModel.results.map(\.status), [.idle, .idle])
    }

    func testRapidTypingOnlyRunsFinalDebouncedRequest() {
        let scheduler = ManualDebounceScheduler()
        let viewModel = makeViewModel(scheduler: scheduler)

        viewModel.setText("h", for: .spanish)
        viewModel.setText("ho", for: .spanish)
        viewModel.setText("hola", for: .spanish)

        XCTAssertEqual(scheduler.scheduledCount, 3)
        scheduler.runAll()

        XCTAssertEqual(viewModel.pendingRequests.map(\.sourceText), ["hola", "hola"])
        XCTAssertEqual(viewModel.pendingRequests.map(\.sourceLanguageIdentifier), ["es", "es"])
        XCTAssertTrue(viewModel.results.allSatisfy { $0.status == .translating })
    }

    func testFailedTranslationUpdatesOnlyAffectedTarget() throws {
        let viewModel = makeViewModel()
        viewModel.setText("hola", for: .spanish)
        viewModel.flushDebounceForTesting()

        let frenchRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .french }))
        let englishRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .english }))

        viewModel.complete(frenchRequest, translatedText: "bonjour")
        viewModel.fail(englishRequest, message: "No model installed.")

        XCTAssertEqual(viewModel.results.first(where: { $0.target == .french })?.status, .translated("bonjour"))
        XCTAssertEqual(viewModel.results.first(where: { $0.target == .english })?.status, .failed("No model installed."))
    }

    func testCompletedTranslationsAreSavedLocally() throws {
        let viewModel = makeViewModel()
        viewModel.setText("hola", for: .spanish)
        viewModel.flushDebounceForTesting()

        let frenchRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .french }))
        let englishRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .english }))

        viewModel.complete(frenchRequest, translatedText: "bonjour")
        XCTAssertTrue(viewModel.savedTranslations.isEmpty)

        viewModel.complete(englishRequest, translatedText: "hello")

        XCTAssertEqual(viewModel.savedTranslations.count, 1)
        XCTAssertEqual(viewModel.savedTranslations[0].sourceText, "hola")
        XCTAssertEqual(
            viewModel.savedTranslations[0].outputs,
            [
                SavedTranslationOutput(target: .french, text: "bonjour"),
                SavedTranslationOutput(target: .english, text: "hello")
            ]
        )
    }

    func testResetCurrentTranslationKeepsSavedTranslations() throws {
        let viewModel = makeViewModel()
        viewModel.setText("hola", for: .spanish)
        viewModel.flushDebounceForTesting()

        let frenchRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .french }))
        let englishRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .english }))
        viewModel.complete(frenchRequest, translatedText: "bonjour")
        viewModel.complete(englishRequest, translatedText: "hello")
        viewModel.resetCurrentTranslation()

        XCTAssertEqual(viewModel.sourceText, "")
        XCTAssertTrue(viewModel.pendingRequests.isEmpty)
        XCTAssertFalse(viewModel.savedTranslations.isEmpty)
        XCTAssertEqual(viewModel.results.map(\.status), [.idle, .idle])
    }

    func testClearSavedTranslationsRemovesHistory() throws {
        let viewModel = makeViewModel()
        viewModel.setText("hola", for: .spanish)
        viewModel.flushDebounceForTesting()

        let frenchRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .french }))
        let englishRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .english }))
        viewModel.complete(frenchRequest, translatedText: "bonjour")
        viewModel.complete(englishRequest, translatedText: "hello")
        viewModel.clearSavedTranslations()

        XCTAssertTrue(viewModel.savedTranslations.isEmpty)
    }

    func testClearResultOnlyClearsGivenLanguageBox() throws {
        let viewModel = makeViewModel()
        viewModel.setText("hola", for: .spanish)
        viewModel.flushDebounceForTesting()

        let frenchRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .french }))
        let englishRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .english }))
        viewModel.complete(frenchRequest, translatedText: "bonjour")
        viewModel.complete(englishRequest, translatedText: "hello")

        viewModel.clearResult(for: .french)
        viewModel.complete(frenchRequest, translatedText: "salut")

        XCTAssertEqual(viewModel.results.first(where: { $0.target == .french })?.status, .idle)
        XCTAssertEqual(viewModel.text(for: .french), "")
        XCTAssertEqual(viewModel.results.first(where: { $0.target == .english })?.status, .translated("hello"))
    }

    func testTypingInEnglishTranslatesOtherVisiblePanels() throws {
        let viewModel = makeViewModel()

        viewModel.setText("hello", for: .english)
        viewModel.flushDebounceForTesting()

        XCTAssertEqual(viewModel.activeLanguage, .english)
        XCTAssertEqual(viewModel.pendingRequests.map(\.target), [.spanish, .french])
        XCTAssertEqual(viewModel.pendingRequests.map(\.sourceLanguageIdentifier), ["en", "en"])

        let spanishRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .spanish }))
        let frenchRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .french }))
        viewModel.complete(spanishRequest, translatedText: "hola")
        viewModel.complete(frenchRequest, translatedText: "bonjour")

        XCTAssertEqual(viewModel.text(for: .english), "hello")
        XCTAssertEqual(viewModel.text(for: .spanish), "hola")
        XCTAssertEqual(viewModel.text(for: .french), "bonjour")
    }

    func testCanSwitchMainLanguage() {
        let viewModel = makeViewModel()

        viewModel.setMainLanguage(.english)

        XCTAssertEqual(viewModel.mainLanguage, .english)
    }

    func testSourcePanelShowsTranslatedWhenBatchCompletes() throws {
        let viewModel = makeViewModel()
        viewModel.setMainLanguage(.english)
        viewModel.setText("hello", for: .english)
        viewModel.flushDebounceForTesting()

        let spanishRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .spanish }))
        let frenchRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .french }))
        viewModel.complete(spanishRequest, translatedText: "hola")
        viewModel.complete(frenchRequest, translatedText: "bonjour")

        XCTAssertTrue(viewModel.pendingRequests.isEmpty)
        XCTAssertEqual(
            viewModel.panels.first(where: { $0.language == .english })?.status,
            .translated("hello")
        )
    }

    func testSamePhraseOnlyCreatesOneHistoryRecord() throws {
        let viewModel = makeViewModel()

        viewModel.setText("hola", for: .spanish)
        viewModel.flushDebounceForTesting()
        var frenchRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .french }))
        var englishRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .english }))
        viewModel.complete(frenchRequest, translatedText: "bonjour")
        viewModel.complete(englishRequest, translatedText: "hello")

        viewModel.setText("  HOLA  ", for: .spanish)
        viewModel.flushDebounceForTesting()
        frenchRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .french }))
        englishRequest = try XCTUnwrap(viewModel.pendingRequests.first(where: { $0.target == .english }))
        viewModel.complete(frenchRequest, translatedText: "salut")
        viewModel.complete(englishRequest, translatedText: "hi")

        XCTAssertEqual(viewModel.savedTranslations.count, 1)
        XCTAssertEqual(viewModel.savedTranslations[0].sourceText, "HOLA")
        XCTAssertEqual(
            viewModel.savedTranslations[0].outputs,
            [
                SavedTranslationOutput(target: .french, text: "salut"),
                SavedTranslationOutput(target: .english, text: "hi")
            ]
        )
    }

    func testTonePreferenceIsStoredPerPanel() {
        let viewModel = makeViewModel()

        viewModel.setTone(.formal, for: .french)

        XCTAssertEqual(viewModel.panels.first(where: { $0.language == .french })?.tone, .formal)
        XCTAssertEqual(viewModel.panels.first(where: { $0.language == .english })?.tone, .automatic)
    }

    func testRestoringHistoryRecordFeedsVisiblePanels() {
        let viewModel = makeViewModel()
        let record = SavedTranslationRecord(
            id: UUID(),
            sourceText: "hello",
            sourceLanguageIdentifier: "en",
            outputs: [
                SavedTranslationOutput(target: .spanish, text: "hola"),
                SavedTranslationOutput(target: .french, text: "bonjour")
            ]
        )

        viewModel.restore(record)

        XCTAssertTrue(viewModel.pendingRequests.isEmpty)
        XCTAssertEqual(viewModel.activeLanguage, .english)
        XCTAssertEqual(viewModel.text(for: .english), "hello")
        XCTAssertEqual(viewModel.text(for: .spanish), "hola")
        XCTAssertEqual(viewModel.text(for: .french), "bonjour")
    }

    private func makeViewModel(
        scheduler: DebounceScheduling = ManualDebounceScheduler()
    ) -> TranslatorViewModel {
        let defaults = MemoryDefaults()
        return TranslatorViewModel(
            settingsStore: LanguageSettingsStore(defaults: defaults),
            historyStore: TranslationHistoryStore(defaults: defaults),
            scheduler: scheduler,
            debounceInterval: 0.35
        )
    }
}

final class ManualDebounceScheduler: DebounceScheduling, @unchecked Sendable {
    private var entries: [Entry] = []

    var scheduledCount: Int {
        entries.count
    }

    func schedule(after interval: TimeInterval, operation: @escaping @MainActor @Sendable () -> Void) -> any CancellableTask {
        let entry = Entry(operation: operation)
        entries.append(entry)
        return AnyCancellableTask {
            entry.cancel()
        }
    }

    @MainActor
    func runAll() {
        entries.forEach { $0.runIfActive() }
    }

    private final class Entry: @unchecked Sendable {
        private var isCancelled = false
        private let operation: @MainActor @Sendable () -> Void

        init(operation: @escaping @MainActor @Sendable () -> Void) {
            self.operation = operation
        }

        func cancel() {
            isCancelled = true
        }

        @MainActor
        func runIfActive() {
            guard !isCancelled else { return }
            operation()
        }
    }
}
