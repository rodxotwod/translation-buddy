import Foundation

public struct TranslationTarget: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let languageIdentifier: String

    public init(id: String? = nil, displayName: String, languageIdentifier: String) {
        self.languageIdentifier = languageIdentifier
        self.displayName = displayName
        self.id = id ?? languageIdentifier
    }

    public static let french = TranslationTarget(displayName: "French", languageIdentifier: "fr")
    public static let english = TranslationTarget(displayName: "English", languageIdentifier: "en")
    public static let spanish = TranslationTarget(displayName: "Spanish", languageIdentifier: "es")
    public static let german = TranslationTarget(displayName: "German", languageIdentifier: "de")
    public static let italian = TranslationTarget(displayName: "Italian", languageIdentifier: "it")
    public static let portuguese = TranslationTarget(displayName: "Portuguese", languageIdentifier: "pt")
    public static let japanese = TranslationTarget(displayName: "Japanese", languageIdentifier: "ja")
    public static let korean = TranslationTarget(displayName: "Korean", languageIdentifier: "ko")
    public static let chineseSimplified = TranslationTarget(displayName: "Chinese Simplified", languageIdentifier: "zh-Hans")

    public static let defaultTargets: [TranslationTarget] = [.french, .english]

    public static let selectableTargets: [TranslationTarget] = [
        .french,
        .english,
        .german,
        .italian,
        .portuguese,
        .japanese,
        .korean,
        .chineseSimplified
    ]
}
