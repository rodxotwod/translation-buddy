import Foundation

public enum TranslationStatus: Equatable, Sendable {
    case idle
    case translating
    case translated(String)
    case failed(String)
}

public struct TranslationResult: Identifiable, Equatable, Sendable {
    public let id: String
    public let target: TranslationTarget
    public var status: TranslationStatus

    public init(target: TranslationTarget, status: TranslationStatus = .idle) {
        self.id = target.id
        self.target = target
        self.status = status
    }
}

public struct TranslationRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let batchID: UUID
    public let sourceText: String
    public let target: TranslationTarget

    public init(id: UUID = UUID(), batchID: UUID = UUID(), sourceText: String, target: TranslationTarget) {
        self.id = id
        self.batchID = batchID
        self.sourceText = sourceText
        self.target = target
    }
}
