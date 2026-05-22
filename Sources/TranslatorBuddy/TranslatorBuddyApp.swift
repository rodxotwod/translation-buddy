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
                onShortcutChanged: { AppServices.shared.shortcutChanged() }
            )
        }
    }
}

@MainActor
final class AppServices {
    static let shared = AppServices()

    let viewModel = TranslatorViewModel()
    let shortcutStore = ShortcutSettingsStore()
    lazy var hotkeyController = HotkeyController(shortcutStore: shortcutStore) { [weak self] in
        Task { @MainActor in
            self?.togglePanel()
        }
    }
    lazy var settingsWindowController = SettingsWindowController(
        viewModel: viewModel,
        shortcutStore: shortcutStore,
        onShortcutChanged: { AppServices.shared.shortcutChanged() }
    )
    lazy var panelController = FloatingPanelController(
        viewModel: viewModel,
        onOpenSettings: { AppServices.shared.openSettings() }
    )

    private init() {}

    func togglePanel() {
        panelController.toggle()
    }

    func openSettings() {
        settingsWindowController.show()
    }

    func shortcutChanged() {
        hotkeyController.register()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        _ = AppServices.shared.panelController
        _ = AppServices.shared.settingsWindowController
        AppServices.shared.hotkeyController.register()
        AppServices.shared.panelController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppServices.shared.hotkeyController.unregister()
    }
}
