import AppKit
import Combine
import SwiftUI

@MainActor
final class WorkspacePanelController: NSWindowController, NSWindowDelegate {
    let model: WorkspaceViewModel
    let settings: PanelSettings
    var openControl: (() -> Void)?
    private let triggers = PanelTriggers()
    private var settingsObserver: AnyCancellable?

    init(model: WorkspaceViewModel, settings: PanelSettings) {
        self.model = model
        self.settings = settings
        let panel = WorkspaceDisplayPanel(
            contentRect: NSRect(x: 0, y: 0, width: PanelAppearance.defaultWidth, height: 700),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.title = L10n.text("workspace.title")
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        super.init(window: panel)
        panel.delegate = self

        let effect = PanelGlassView(frame: .zero)
        let content = NSHostingView(rootView: WorkspacePanelView(model: model, panelSettings: settings, close: { [weak self] in
            self?.collapse()
        }, settings: { [weak self] in
            self?.collapse()
            self?.openControl?()
        }))
        content.sizingOptions = []
        content.translatesAutoresizingMaskIntoConstraints = false
        // Keep the background translucent without fading text, icons, or controls.
        effect.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            content.topAnchor.constraint(equalTo: effect.topAnchor),
            content.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
        ])
        panel.contentView = effect
        triggers.show = { [weak self] in self?.present() }
        triggers.toggle = { [weak self] in self?.toggle() }
        triggers.shortcutFailed = { [weak self] in self?.model.error = L10n.text("panel.shortcutFailed") }
        triggers.configure(settings)
        settingsObserver = settings.objectWillChange.receive(on: RunLoop.main).sink { [weak self] in
            guard let self else { return }
            self.triggers.configure(self.settings)
            if self.window?.isVisible == true { self.position() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        position()
        window?.makeKeyAndOrderFront(nil)
    }

    private func position() {
        // Use the display containing the pointer; do not move any other application's windows.
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let screen {
            window?.setFrame(PanelAppearance.frame(in: screen.visibleFrame, width: settings.width, leftSide: settings.leftSide), display: true)
        }
    }

    func toggle() {
        if window?.isVisible == true { collapse() } else { present() }
    }

    func collapse() { window?.orderOut(nil) }

    func windowDidResignKey(_ notification: Notification) {
        // Only the display panel collapses. Editing remains in the independent control window.
        collapse()
    }

    func stop() { triggers.stop() }
}
