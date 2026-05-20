import AppKit
import SwiftUI
import TranslatorBuddyCore

@MainActor
final class SettingsWindowController {
    private let viewModel: TranslatorViewModel
    private let shortcutStore: ShortcutSettingsStore
    private let onShortcutChanged: () -> Void
    private var window: NSWindow?

    init(
        viewModel: TranslatorViewModel,
        shortcutStore: ShortcutSettingsStore,
        onShortcutChanged: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.shortcutStore = shortcutStore
        self.onShortcutChanged = onShortcutChanged
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Translator Buddy Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView(
                viewModel: viewModel,
                shortcutStore: shortcutStore,
                onShortcutChanged: onShortcutChanged
            )
        )
        return window
    }
}
