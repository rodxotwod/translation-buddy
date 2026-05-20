import AppKit
import SwiftUI
import TranslatorBuddyCore

@main
struct TranslatorBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                viewModel: AppServices.shared.viewModel,
                shortcutStore: AppServices.shared.shortcutStore,
                hotkeyController: AppServices.shared.hotkeyController
            )
        }
    }
}

@MainActor
final class AppServices {
    static let shared = AppServices()

    let viewModel = TranslatorViewModel()
    let shortcutStore = ShortcutSettingsStore()
    lazy var panelController = FloatingPanelController(viewModel: viewModel)
    lazy var hotkeyController = HotkeyController(shortcutStore: shortcutStore) {
        Task { @MainActor in
            AppServices.shared.panelController.toggle()
        }
    }

    private init() {}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        _ = AppServices.shared.panelController
        AppServices.shared.hotkeyController.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppServices.shared.hotkeyController.unregister()
    }
}
