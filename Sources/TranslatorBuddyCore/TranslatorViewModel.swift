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

    @Published public var sourceText: String = "" {
        didSet { scheduleTranslation() }
    }

    @Published public private(set) var targets: [TranslationTarget]
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
        updateStatus(for: request.target, status: .translating)
    }

    public func complete(_ request: TranslationRequest, translatedText: String) {
        guard isCurrent(request) else { return }
        updateStatus(for: request.target, status: .translated(translatedText))
        saveCurrentTranslation(for: request)
    }

    public func fail(_ request: TranslationRequest, message: String) {
        guard isCurrent(request) else { return }
        updateStatus(for: request.target, status: .failed(message))
    }

    public func clearSettingsError() {
        lastSettingsError = nil
    }

    public func resetCurrentTranslation() {
        pendingDebounce?.cancel()
        sourceText = ""
        pendingRequests = []
        results = targets.map { TranslationResult(target: $0) }
    }

    public func clearSavedTranslations() {
        savedTranslations = []
        historyStore.clear()
    }

    public func flushDebounceForTesting() {
        pendingDebounce?.cancel()
        issueRequests()
    }

    private func scheduleTranslation() {
        pendingDebounce?.cancel()

        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            pendingRequests = []
            results = targets.map { TranslationResult(target: $0) }
            return
        }

        pendingDebounce = scheduler.schedule(after: debounceInterval) { [weak self] in
            self?.issueRequests()
        }
    }

    private func issueRequests() {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            pendingRequests = []
            results = targets.map { TranslationResult(target: $0) }
            return
        }

        let batchID = UUID()
        let requests = targets.map { TranslationRequest(batchID: batchID, sourceText: trimmed, target: $0) }
        pendingRequests = requests
        results = targets.map { TranslationResult(target: $0, status: .translating) }
    }

    private func persistTargetsAndRefreshResults() {
        settingsStore.saveTargets(targets)
        results = targets.map { target in
            results.first(where: { $0.target.languageIdentifier == target.languageIdentifier })
                ?? TranslationResult(target: target)
        }
        lastSettingsError = nil
        scheduleTranslation()
    }

    private func updateStatus(for target: TranslationTarget, status: TranslationStatus) {
        results = results.map { result in
            guard result.target.languageIdentifier == target.languageIdentifier else {
                return result
            }

            return TranslationResult(target: target, status: status)
        }
    }

    private func isCurrent(_ request: TranslationRequest) -> Bool {
        pendingRequests.contains(request)
    }

    private func saveCurrentTranslation(for request: TranslationRequest) {
        let outputs = results.compactMap { result -> SavedTranslationOutput? in
            guard case .translated(let text) = result.status else {
                return nil
            }

            return SavedTranslationOutput(target: result.target, text: text)
        }

        guard !outputs.isEmpty else { return }

        let record = SavedTranslationRecord(
            id: request.batchID,
            sourceText: request.sourceText,
            sourceLanguageIdentifier: Self.sourceLanguageIdentifier,
            outputs: outputs
        )
        savedTranslations = historyStore.upsert(record, into: savedTranslations)
        historyStore.saveRecords(savedTranslations)
    }
}
