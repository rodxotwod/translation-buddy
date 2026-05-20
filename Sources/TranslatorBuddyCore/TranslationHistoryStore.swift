import Foundation

public struct SavedTranslationOutput: Codable, Equatable, Sendable {
    public let target: TranslationTarget
    public let text: String

    public init(target: TranslationTarget, text: String) {
        self.target = target
        self.text = text
    }
}

public struct SavedTranslationRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let sourceText: String
    public let sourceLanguageIdentifier: String
    public let outputs: [SavedTranslationOutput]

    public init(
        id: UUID,
        createdAt: Date = Date(),
        sourceText: String,
        sourceLanguageIdentifier: String,
        outputs: [SavedTranslationOutput]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceText = sourceText
        self.sourceLanguageIdentifier = sourceLanguageIdentifier
        self.outputs = outputs
    }
}

public final class TranslationHistoryStore: @unchecked Sendable {
    public static let defaultKey = "translatorBuddy.savedTranslations"

    private let key: String
    private let defaults: KeyValueStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxRecords: Int

    public init(
        defaults: KeyValueStore = UserDefaults.standard,
        key: String = TranslationHistoryStore.defaultKey,
        maxRecords: Int = 100
    ) {
        self.defaults = defaults
        self.key = key
        self.maxRecords = maxRecords
    }

    public func loadRecords() -> [SavedTranslationRecord] {
        guard
            let data = defaults.data(forKey: key),
            let records = try? decoder.decode([SavedTranslationRecord].self, from: data)
        else {
            return []
        }

        return records
    }

    public func saveRecords(_ records: [SavedTranslationRecord]) {
        let trimmedRecords = Array(records.prefix(maxRecords))
        guard let data = try? encoder.encode(trimmedRecords) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    public func upsert(_ record: SavedTranslationRecord, into records: [SavedTranslationRecord]) -> [SavedTranslationRecord] {
        let nextRecords = records.filter { $0.id != record.id }
        return ([record] + nextRecords).prefixArray(maxRecords)
    }

    public func clear() {
        defaults.set(nil, forKey: key)
    }
}

private extension Array {
    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
}
