import AppKit
import SwiftUI

@MainActor
final class WorkspaceControlController: NSWindowController {
    init(model: WorkspaceViewModel, settings: PanelSettings, showPanel: @escaping () -> Void) {
        let contentRect = NSRect(x: 0, y: 0, width: 920, height: 540)
        let window = NSWindow(contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L10n.text("control.title")
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: WorkspaceControlView(model: model, settings: settings, showPanel: showPanel))
        window.addTitlebarAccessoryViewController(ControlTitlebarAccessory(showPanel: showPanel))
        // Hosting can replace the initial content size before SwiftUI's first layout.
        window.setContentSize(contentRect.size)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        // Center after SwiftUI resolves the displayed window size, including on later openings.
        window.contentView?.layoutSubtreeIfNeeded()
        window.center()
        NSApplication.shared.activate()
    }
}
