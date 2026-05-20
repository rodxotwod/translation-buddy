import AppKit
import SwiftUI
import TranslatorBuddyCore

@MainActor
final class FloatingPanelController {
    private let viewModel: TranslatorViewModel
    private let onOpenSettings: () -> Void
    private var panel: SpotlightPanel?

    init(viewModel: TranslatorViewModel, onOpenSettings: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onOpenSettings = onOpenSettings
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
        center(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> SpotlightPanel {
        let panel = SpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "Translator Buddy"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
        panel.onCancel = { [weak self] in self?.hide() }
        panel.contentView = NSHostingView(
            rootView: TranslatorPanelView(
                viewModel: viewModel,
                onClose: { [weak self] in self?.hide() },
                onOpenSettings: onOpenSettings
            )
        )

        return panel
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
