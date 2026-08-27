import AppKit
import SwiftUI

@MainActor
final class DiagnosticsWindowController: NSWindowController {
    init() {
        // A development diagnostics window, not the final edge panel or its dimensions.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("diagnostics.windowTitle")
        window.contentViewController = NSHostingController(rootView: DiagnosticsView())
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
}
