import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var diagnosticsController: DiagnosticsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.split.2x1",
            accessibilityDescription: L10n.text("app.name")
        )
        item.button?.toolTip = L10n.text("app.name")

        let menu = NSMenu()
        let diagnostics = NSMenuItem(
            title: L10n.text("menu.diagnostics"),
            action: #selector(showDiagnostics),
            keyEquivalent: ""
        )
        diagnostics.target = self
        menu.addItem(diagnostics)
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: L10n.text("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApplication.shared
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc private func showDiagnostics() {
        if diagnosticsController == nil {
            diagnosticsController = DiagnosticsWindowController()
        }
        diagnosticsController?.showWindow(nil)
        NSApplication.shared.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
