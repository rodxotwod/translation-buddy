import Carbon
import Combine
import Foundation

struct ShortcutPreference: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    let displayName: String
    let keyCode: UInt32
    let modifierFlags: UInt32

    static let optionSpace = ShortcutPreference(
        id: "option-space",
        displayName: "Option + Space",
        keyCode: UInt32(kVK_Space),
        modifierFlags: UInt32(optionKey)
    )

    static let commandShiftSpace = ShortcutPreference(
        id: "command-shift-space",
        displayName: "Command + Shift + Space",
        keyCode: UInt32(kVK_Space),
        modifierFlags: UInt32(cmdKey | shiftKey)
    )

    static let controlSpace = ShortcutPreference(
        id: "control-space",
        displayName: "Control + Space",
        keyCode: UInt32(kVK_Space),
        modifierFlags: UInt32(controlKey)
    )

    static let controlOptionSpace = ShortcutPreference(
        id: "control-option-space",
        displayName: "Control + Option + Space",
        keyCode: UInt32(kVK_Space),
        modifierFlags: UInt32(controlKey | optionKey)
    )

    static let commandOptionSpace = ShortcutPreference(
        id: "command-option-space",
        displayName: "Command + Option + Space",
        keyCode: UInt32(kVK_Space),
        modifierFlags: UInt32(cmdKey | optionKey)
    )

    static let controlOptionT = ShortcutPreference(
        id: "control-option-t",
        displayName: "Control + Option + T",
        keyCode: UInt32(kVK_ANSI_T),
        modifierFlags: UInt32(controlKey | optionKey)
    )

    static let presets: [ShortcutPreference] = [
        .optionSpace,
        .commandShiftSpace,
        .controlSpace,
        .controlOptionSpace,
        .commandOptionSpace,
        .controlOptionT
    ]
}

@MainActor
final class ShortcutSettingsStore: ObservableObject {
    static let defaultKey = "translatorBuddy.shortcutPreference"

    @Published var preference: ShortcutPreference {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard, key: String = ShortcutSettingsStore.defaultKey) {
        self.defaults = defaults
        self.key = key
        self.preference = Self.load(defaults: defaults, key: key)
    }

    private static func load(defaults: UserDefaults, key: String) -> ShortcutPreference {
        guard
            let data = defaults.data(forKey: key),
            let preference = try? JSONDecoder().decode(ShortcutPreference.self, from: data),
            ShortcutPreference.presets.contains(preference)
        else {
            return .optionSpace
        }

        return preference
    }

    private func save() {
        guard let data = try? encoder.encode(preference) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
