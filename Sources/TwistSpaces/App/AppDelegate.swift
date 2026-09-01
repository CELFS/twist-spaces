import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var diagnosticsController: DiagnosticsWindowController?
    private var workspaceController: WorkspacePanelController?
    private var controlController: WorkspaceControlController?
    private var launchHUDController: WorkspaceLaunchHUDController?
    private var statusMenu: NSMenu?
    private var languageObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        let settings = PanelSettings()
        let model = WorkspaceViewModel(minimumWindowAge: { settings.windowStabilityDelay })
        launchHUDController = WorkspaceLaunchHUDController(model: model)
        workspaceController = WorkspacePanelController(model: model, settings: settings)
        controlController = WorkspaceControlController(model: model, settings: settings, showPanel: { [weak self] in
            self?.workspaceController?.present()
        })
        workspaceController?.openControl = { [weak self] in self?.showControl() }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.split.2x1",
            accessibilityDescription: L10n.text("app.name")
        )
        item.button?.toolTip = L10n.text("app.name")
        item.button?.target = self
        item.button?.action = #selector(statusClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        configureStatusMenu()
        controlController?.present()
        languageObserver = LanguageSettings.shared.$selection.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            self?.configureMainMenu()
            self?.configureStatusMenu()
            self?.controlController?.window?.title = L10n.text("control.title")
            self?.workspaceController?.window?.title = L10n.text("workspace.title")
            self?.diagnosticsController?.window?.title = L10n.text("diagnostics.windowTitle")
        }
    }

    private func configureStatusMenu() {
        let menu = NSMenu()
        let workspaces = NSMenuItem(title: L10n.text("menu.workspaces"), action: #selector(showWorkspaces), keyEquivalent: "")
        workspaces.target = self
        menu.addItem(workspaces)
        let settings = NSMenuItem(title: L10n.text("control.title"), action: #selector(showControl), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        #if DEBUG
        let developer = NSMenuItem(title: L10n.text("menu.developer"), action: nil, keyEquivalent: "")
        let developerMenu = NSMenu()
        let diagnostics = NSMenuItem(
            title: L10n.text("menu.diagnostics"),
            action: #selector(showDiagnostics),
            keyEquivalent: ""
        )
        diagnostics.target = self
        developerMenu.addItem(diagnostics)
        developer.submenu = developerMenu
        menu.addItem(developer)
        menu.addItem(.separator())
        #endif

        let restart = NSMenuItem(title: L10n.text("action.restart"),
                                 action: #selector(ApplicationRestarter.restart(_:)), keyEquivalent: "")
        restart.target = ApplicationRestarter.shared
        menu.addItem(restart)
        let quit = NSMenuItem(
            title: L10n.text("action.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApplication.shared
        menu.addItem(quit)
        statusMenu = menu
    }

    private func configureMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: L10n.text("app.name"))
        appMenu.addItem(withTitle: L10n.text("menu.workspaces"), action: #selector(showWorkspaces), keyEquivalent: "1").target = self
        appMenu.addItem(withTitle: L10n.text("control.title"), action: #selector(showControl), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.text("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApplication.shared
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: L10n.text("menu.edit"))
        for (key, action, shortcut) in [("menu.undo", Selector(("undo:")), "z"), ("menu.cut", #selector(NSText.cut(_:)), "x"), ("menu.copy", #selector(NSText.copy(_:)), "c"), ("menu.paste", #selector(NSText.paste(_:)), "v"), ("menu.selectAll", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: L10n.text(key), action: action, keyEquivalent: shortcut)
        }
        editItem.submenu = edit
        main.addItem(editItem)
        NSApplication.shared.mainMenu = main
    }

    @objc private func statusClicked() {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp, let button = statusItem?.button {
            statusMenu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else {
            workspaceController?.toggle()
        }
    }

    @objc private func showWorkspaces() { workspaceController?.present() }
    @objc private func showControl() {
        workspaceController?.collapse()
        controlController?.present()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControl()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { workspaceController?.stop() }

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
