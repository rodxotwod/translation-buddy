import Foundation
import Combine

public protocol DebounceScheduling: AnyObject, Sendable {
    @discardableResult
    func schedule(after interval: TimeInterval, operation: @escaping @MainActor @Sendable () -> Void) -> any CancellableTask
}

public protocol CancellableTask: Sendable {
    func cancel()
}

public final class TaskDebounceScheduler: DebounceScheduling {
    public init() {}

    public func schedule(after interval: TimeInterval, operation: @escaping @MainActor @Sendable () -> Void) -> any CancellableTask {
        let task = Task { @MainActor in
            let nanoseconds = UInt64(max(0, interval) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            operation()
        }

        return AnyCancellableTask { task.cancel() }
    }
}

public final class AnyCancellableTask: CancellableTask, @unchecked Sendable {
    private let onCancel: @Sendable () -> Void

    public init(_ onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel()
    }
}

@MainActor
public final class TranslatorViewModel: ObservableObject {
    public static let sourceLanguageIdentifier = "es"

    @Published public private(set) var sourceText: String = ""
    @Published public private(set) var activeLanguage: TranslationTarget = .spanish
    @Published public private(set) var targets: [TranslationTarget]
    @Published public private(set) var panels: [LanguagePanelState]
    @Published public private(set) var results: [TranslationResult]
    @Published public private(set) var pendingRequests: [TranslationRequest] = []
    @Published public private(set) var savedTranslations: [SavedTranslationRecord]
    @Published public var lastSettingsError: String?

    private let settingsStore: LanguageSettingsStore
    private let historyStore: TranslationHistoryStore
    private let scheduler: DebounceScheduling
    private let debounceInterval: TimeInterval
    private var pendingDebounce: (any CancellableTask)?

    public init(
        settingsStore: LanguageSettingsStore = LanguageSettingsStore(),
        historyStore: TranslationHistoryStore = TranslationHistoryStore(),
        scheduler: DebounceScheduling = TaskDebounceScheduler(),
        debounceInterval: TimeInterval = 0.35
    ) {
        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.scheduler = scheduler
        self.debounceInterval = debounceInterval
        let loadedTargets = settingsStore.loadTargets()
        self.targets = loadedTargets
        self.panels = Self.makePanels(for: loadedTargets)
        self.results = loadedTargets.map { TranslationResult(target: $0) }
        self.savedTranslations = historyStore.loadRecords()
    }

    public func addTarget(_ target: TranslationTarget) {
        do {
            targets = try settingsStore.add(target, to: targets)
            persistTargetsAndRefreshResults()
        } catch LanguageSettingsError.duplicateTarget {
            lastSettingsError = "\(target.displayName) is already enabled."
        } catch {
            lastSettingsError = "Could not add \(target.displayName)."
        }
    }

    public func removeTarget(_ target: TranslationTarget) {
        do {
            targets = try settingsStore.remove(target, from: targets)
            persistTargetsAndRefreshResults()
        } catch LanguageSettingsError.cannotRemoveLastTarget {
            lastSettingsError = "Keep at least one target language."
        } catch {
            lastSettingsError = "Could not remove \(target.displayName)."
        }
    }

    public func setTarget(_ target: TranslationTarget, isEnabled: Bool) {
        do {
            let nextTargets: [TranslationTarget]
            if isEnabled {
                nextTargets = try settingsStore.add(target, to: targets)
            } else {
                nextTargets = try settingsStore.remove(target, from: targets)
            }

            targets = try settingsStore.setTargets(nextTargets)
            persistTargetsAndRefreshResults()
        } catch LanguageSettingsError.duplicateTarget {
            lastSettingsError = "\(target.displayName) is already enabled."
        } catch LanguageSettingsError.cannotRemoveLastTarget {
            lastSettingsError = "Keep at least one target language."
        } catch {
            lastSettingsError = "Could not update target languages."
        }
    }

    public func markTranslating(_ request: TranslationRequest) {
        updatePanel(for: request.target, status: .translating)
    }

    public func complete(_ request: TranslationRequest, translatedText: String) {
        guard isCurrent(request) else { return }
        updatePanel(for: request.target, text: translatedText, status: .translated(translatedText))
        saveCurrentTranslation(for: request)
    }

    public func fail(_ request: TranslationRequest, message: String) {
        guard isCurrent(request) else { return }
        updatePanel(for: request.target, status: .failed(message))
    }

    public func clearSettingsError() {
        lastSettingsError = nil
    }

    public func resetCurrentTranslation() {
        pendingDebounce?.cancel()
        sourceText = ""
        pendingRequests = []
        panels = visibleLanguages.map { LanguagePanelState(language: $0) }
        syncResultsFromPanels()
    }

    public func clearSavedTranslations() {
        savedTranslations = []
        historyStore.clear()
    }

    public func clearResult(for target: TranslationTarget) {
        pendingRequests = pendingRequests.filter { $0.target.languageIdentifier != target.languageIdentifier }
        updatePanel(for: target, text: "", status: .idle)
    }

    public func text(for language: TranslationTarget) -> String {
        panels.first { $0.language.languageIdentifier == language.languageIdentifier }?.text ?? ""
    }

    public func setText(_ text: String, for language: TranslationTarget) {
        pendingDebounce?.cancel()
        activeLanguage = language
        updatePanel(for: language, text: text, status: .idle)

        if language == .spanish {
            sourceText = text
        }

        scheduleTranslation(from: language)
    }

    public func flushDebounceForTesting() {
        pendingDebounce?.cancel()
        issueRequests(from: activeLanguage)
    }

    private func scheduleTranslation(from language: TranslationTarget) {
        pendingDebounce?.cancel()

        let trimmed = text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            pendingRequests = []
            panels = visibleLanguages.map { LanguagePanelState(language: $0) }
            sourceText = ""
            syncResultsFromPanels()
            return
        }

        pendingDebounce = scheduler.schedule(after: debounceInterval) { [weak self] in
            self?.issueRequests(from: language)
        }
    }

    private func issueRequests(from language: TranslationTarget) {
        let trimmed = text(for: language).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            pendingRequests = []
            panels = visibleLanguages.map { LanguagePanelState(language: $0) }
            sourceText = ""
            syncResultsFromPanels()
            return
        }

        let batchID = UUID()
        let requests = visibleLanguages
            .filter { $0.languageIdentifier != language.languageIdentifier }
            .map {
                TranslationRequest(
                    batchID: batchID,
                    sourceLanguageIdentifier: language.languageIdentifier,
                    sourceText: trimmed,
                    target: $0
                )
            }
        pendingRequests = requests
        panels = panels.map { panel in
            guard panel.language.languageIdentifier != language.languageIdentifier else {
                return LanguagePanelState(language: panel.language, text: panel.text, status: .idle)
            }

            return LanguagePanelState(language: panel.language, text: panel.text, status: .translating)
        }
        syncResultsFromPanels()
    }

    private func persistTargetsAndRefreshResults() {
        settingsStore.saveTargets(targets)
        panels = visibleLanguages.map { language in
            panels.first(where: { $0.language.languageIdentifier == language.languageIdentifier })
                ?? LanguagePanelState(language: language)
        }
        if !visibleLanguages.contains(where: { $0.languageIdentifier == activeLanguage.languageIdentifier }) {
            activeLanguage = .spanish
        }
        lastSettingsError = nil
        syncResultsFromPanels()
        scheduleTranslation(from: activeLanguage)
    }

    private var visibleLanguages: [TranslationTarget] {
        [.spanish] + targets
    }

    private static func makePanels(for targets: [TranslationTarget]) -> [LanguagePanelState] {
        ([.spanish] + targets).map { LanguagePanelState(language: $0) }
    }

    private func updatePanel(for language: TranslationTarget, text: String? = nil, status: TranslationStatus) {
        panels = panels.map { panel in
            guard panel.language.languageIdentifier == language.languageIdentifier else {
                return panel
            }

            return LanguagePanelState(
                language: panel.language,
                text: text ?? panel.text,
                status: status
            )
        }

        if language == .spanish, let text {
            sourceText = text
        }

        syncResultsFromPanels()
    }

    private func syncResultsFromPanels() {
        results = targets.map { target in
            let panel = panels.first { $0.language.languageIdentifier == target.languageIdentifier }
            return TranslationResult(target: target, status: panel?.status ?? .idle)
        }
    }

    private func isCurrent(_ request: TranslationRequest) -> Bool {
        pendingRequests.contains(request)
    }

    private func saveCurrentTranslation(for request: TranslationRequest) {
        let outputs = panels.compactMap { panel -> SavedTranslationOutput? in
            guard
                panel.language.languageIdentifier != request.sourceLanguageIdentifier,
                case .translated = panel.status,
                !panel.text.isEmpty
            else {
                return nil
            }

            return SavedTranslationOutput(target: panel.language, text: panel.text)
        }

        guard !outputs.isEmpty else { return }

        let record = SavedTranslationRecord(
            id: request.batchID,
            sourceText: request.sourceText,
            sourceLanguageIdentifier: request.sourceLanguageIdentifier,
            outputs: outputs
        )
        savedTranslations = historyStore.upsert(record, into: savedTranslations)
        historyStore.saveRecords(savedTranslations)
    }
}
