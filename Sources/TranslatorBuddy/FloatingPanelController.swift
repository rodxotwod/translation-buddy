import AppKit
import SwiftUI
import TranslatorBuddyCore

@MainActor
final class FloatingPanelController {
    private let viewModel: TranslatorViewModel
    private let windowSettingsStore: WindowSettingsStore
    private let onOpenSettings: () -> Void
    private var panel: SpotlightPanel?

    init(
        viewModel: TranslatorViewModel,
        windowSettingsStore: WindowSettingsStore,
        onOpenSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.windowSettingsStore = windowSettingsStore
        self.onOpenSettings = onOpenSettings
        self.windowSettingsStore.onKeepAboveOtherAppsChanged = { [weak self] _ in
            self?.applyWindowLevel()
        }
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        applyWindowLevel()
        center(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        windowSettingsStore.requestMainPanelFocus()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> SpotlightPanel {
        let panel = SpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.title = "Translator Buddy"
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 720, height: 500)
        panel.isFloatingPanel = true
        panel.animationBehavior = .utilityWindow
        panel.onCancel = { [weak self] in self?.hide() }
        panel.contentView = NSHostingView(
            rootView: TranslatorPanelView(
                viewModel: viewModel,
                windowSettingsStore: windowSettingsStore,
                onClose: { [weak self] in self?.hide() },
                onOpenSettings: onOpenSettings
            )
        )
        applyWindowLevel(to: panel)

        return panel
    }

    private func applyWindowLevel() {
        guard let panel else {
            return
        }

        applyWindowLevel(to: panel)
    }

    private func applyWindowLevel(to panel: NSPanel) {
        if windowSettingsStore.keepsWindowAboveOtherApps {
            panel.level = .statusBar
            panel.hidesOnDeactivate = false
            panel.canHide = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            if panel.isVisible {
                panel.orderFrontRegardless()
            }
        } else {
            panel.level = .normal
            panel.hidesOnDeactivate = true
            panel.canHide = true
            panel.collectionBehavior = [.transient, .ignoresCycle]
        }
    }

    private func center(_ panel: NSPanel) {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            panel.center()
            return
        }

        let origin = NSPoint(
            x: screenFrame.midX - panel.frame.width / 2,
            y: screenFrame.midY - panel.frame.height / 2 + 80
        )
        panel.setFrameOrigin(origin)
    }
}

final class SpotlightPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
