import AppKit
import SwiftUI

@MainActor
final class WorkspaceControlController: NSWindowController {
    init(model: WorkspaceViewModel, settings: PanelSettings, showPanel: @escaping () -> Void) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L10n.text("control.title")
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: WorkspaceControlView(model: model, settings: settings, showPanel: showPanel))
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }
}
