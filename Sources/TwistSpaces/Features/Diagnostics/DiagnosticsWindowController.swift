import AppKit
import SwiftUI

@MainActor
final class DiagnosticsWindowController: NSWindowController {
    init() {
        // A development diagnostics window, not the final edge panel or its dimensions.
        let contentRect = NSRect(x: 0, y: 0, width: 602, height: 434)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("diagnostics.windowTitle")
        window.contentViewController = NSHostingController(rootView: DiagnosticsView())
        window.isReleasedWhenClosed = false
        // Hosting can replace the initial content size before SwiftUI's first layout.
        window.setContentSize(contentRect.size)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func showWindow(_ sender: Any?) {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        super.showWindow(sender)
        // Center the displayed size on every opening without resetting a user's resize.
        window.contentView?.layoutSubtreeIfNeeded()
        window.center()
    }
}
