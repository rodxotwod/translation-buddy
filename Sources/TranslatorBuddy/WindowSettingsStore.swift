import Combine
import Foundation

@MainActor
final class WindowSettingsStore: ObservableObject {
    static let keepAboveOtherAppsKey = "translatorBuddy.keepAboveOtherApps"

    @Published var focusRequestID = UUID()

    @Published var keepsWindowAboveOtherApps: Bool {
        didSet {
            defaults.set(keepsWindowAboveOtherApps, forKey: key)
            onKeepAboveOtherAppsChanged?(keepsWindowAboveOtherApps)
        }
    }

    var onKeepAboveOtherAppsChanged: ((Bool) -> Void)?

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = WindowSettingsStore.keepAboveOtherAppsKey) {
        self.defaults = defaults
        self.key = key
        self.keepsWindowAboveOtherApps = defaults.bool(forKey: key)
    }

    func requestMainPanelFocus() {
        focusRequestID = UUID()
    }
}
