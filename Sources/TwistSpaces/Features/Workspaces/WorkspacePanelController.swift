import AppKit
import SwiftUI

@MainActor
final class WorkspacePanelController: NSWindowController {
    let model = WorkspaceViewModel()
    let settings = PanelSettings()
    private let triggers = PanelTriggers()
    private var settingsController: NSWindowController?

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 700),
            styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false
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

        let effect = NSVisualEffectView()
        effect.material = .sidebar
        effect.blendingMode = .behindWindow
        effect.state = .active
        let content = NSHostingView(rootView: WorkspacePanelView(model: model, close: { [weak self] in
            self?.window?.orderOut(nil)
        }, settings: { [weak self] in self?.showSettings() }))
        content.translatesAutoresizingMaskIntoConstraints = false
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        // Use the display containing the pointer; do not move any other application's windows.
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let screen {
            let frame = screen.visibleFrame
            let width = min(settings.width, frame.width)
            let x = settings.leftSide ? frame.minX : frame.maxX - width
            window?.setFrame(NSRect(x: x, y: frame.minY, width: width, height: frame.height), display: true)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    func toggle() {
        guard window?.attachedSheet == nil else { present(); return }
        if window?.isVisible == true { window?.orderOut(nil) } else { present() }
    }

    func showSettings() {
        if settingsController == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = L10n.text("panel.settings")
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: PanelSettingsView(settings: settings, done: { [weak self] in
                guard let self else { return }
                self.triggers.configure(self.settings)
                self.settingsController?.close()
                self.present()
            }))
            window.center()
            settingsController = NSWindowController(window: window)
        }
        settingsController?.showWindow(nil)
        NSApplication.shared.activate()
    }

    func stop() { triggers.stop() }
}
