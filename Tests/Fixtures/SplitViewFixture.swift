// Purpose: Provide two disposable native windows for manual Split View integration checks.
// Build and run: bash claude_jobs/build-split-view-fixture.sh
// This fixture never reads workspace data or opens project files. Quit closes both test windows.
import AppKit

@MainActor
final class SplitViewFixtureDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let main = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Split View Fixture")
        applicationMenu.addItem(withTitle: "Quit Split View Fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        main.addItem(applicationItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
        for (index, name) in ["Twist Split Test Left", "Twist Split Test Right"].enumerated() {
            let window = NSWindow(contentRect: NSRect(x: 120 + index * 80, y: 140 + index * 60, width: 760, height: 520),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = name
            window.identifier = NSUserInterfaceItemIdentifier("twist-split-test-\(index)")
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
            window.minSize = NSSize(width: 240, height: 180)
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 28)
            label.translatesAutoresizingMaskIntoConstraints = false
            window.contentView?.addSubview(label)
            if let content = window.contentView {
                NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                                             label.centerYAnchor.constraint(equalTo: content.centerYAnchor)])
            }
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate()
    }
}

let app = NSApplication.shared
let delegate = SplitViewFixtureDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
