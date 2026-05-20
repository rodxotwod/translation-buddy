import Foundation

public enum LanguageSettingsError: Error, Equatable {
    case duplicateTarget
    case cannotRemoveLastTarget
}

public protocol KeyValueStore {
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: KeyValueStore {}

public final class LanguageSettingsStore: @unchecked Sendable {
    public static let defaultKey = "translatorBuddy.targetLanguages"

    private let key: String
    private let defaults: KeyValueStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: KeyValueStore = UserDefaults.standard, key: String = LanguageSettingsStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func loadTargets() -> [TranslationTarget] {
        guard
            let data = defaults.data(forKey: key),
            let targets = try? decoder.decode([TranslationTarget].self, from: data),
            !targets.isEmpty
        else {
            return TranslationTarget.defaultTargets
        }

        return targets
    }

    public func saveTargets(_ targets: [TranslationTarget]) {
        let uniqueTargets = targets.removingDuplicatesByIdentifier()
        guard !uniqueTargets.isEmpty, let data = try? encoder.encode(uniqueTargets) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    public func add(_ target: TranslationTarget, to targets: [TranslationTarget]) throws -> [TranslationTarget] {
        guard !targets.contains(where: { $0.languageIdentifier == target.languageIdentifier }) else {
            throw LanguageSettingsError.duplicateTarget
        }

        return targets + [target]
    }

    public func remove(_ target: TranslationTarget, from targets: [TranslationTarget]) throws -> [TranslationTarget] {
        guard targets.count > 1 else {
            throw LanguageSettingsError.cannotRemoveLastTarget
        }

        let nextTargets = targets.filter { $0.languageIdentifier != target.languageIdentifier }
        guard !nextTargets.isEmpty else {
            throw LanguageSettingsError.cannotRemoveLastTarget
        }

        return nextTargets
    }

    public func setTargets(_ targets: [TranslationTarget]) throws -> [TranslationTarget] {
        let uniqueTargets = targets.removingDuplicatesByIdentifier()
        guard !uniqueTargets.isEmpty else {
            throw LanguageSettingsError.cannotRemoveLastTarget
        }

        return uniqueTargets
    }
}

private extension Array where Element == TranslationTarget {
    func removingDuplicatesByIdentifier() -> [TranslationTarget] {
        var seen = Set<String>()
        return filter { seen.insert($0.languageIdentifier).inserted }
    }
}
