import AppKit
import Combine
import CoreGraphics
import SwiftUI

struct WorkspacePanelDisplay: Equatable {
    let id: CGDirectDisplayID
    let frame: CGRect
    let visibleFrame: CGRect

    @MainActor
    static func active() -> [WorkspacePanelDisplay] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return WorkspacePanelDisplay(id: number.uint32Value, frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
    }
}

@MainActor
final class WorkspacePanelController: NSWindowController, NSWindowDelegate {
    let model: WorkspaceViewModel
    let settings: PanelSettings
    var openControl: (() -> Void)?
    private let triggers = PanelTriggers()
    private let displayProvider: @MainActor () -> [WorkspacePanelDisplay]
    private let panelFactory: @MainActor () -> NSPanel
    private var settingsObserver: AnyCancellable?
    private var pinObserver: AnyCancellable?
    private var secondaryPanels: [CGDirectDisplayID: NSPanel] = [:]
    private var primaryDisplayID: CGDirectDisplayID?
    private weak var overlayWindow: NSWindow?
    private enum Presentation { case hidden, desktop, overlay }
    private var presentation: Presentation = .hidden

    init(model: WorkspaceViewModel, settings: PanelSettings,
         displayProvider: @escaping @MainActor () -> [WorkspacePanelDisplay] = WorkspacePanelDisplay.active,
         panelFactory: @escaping @MainActor () -> NSPanel = WorkspacePanelController.makePanel) {
        self.model = model
        self.settings = settings
        self.displayProvider = displayProvider
        self.panelFactory = panelFactory
        let panel = WorkspacePanelController.makePanel()
        super.init(window: panel)
        installContent(on: panel)

        triggers.show = { [weak self] in self?.present() }
        triggers.toggle = { [weak self] in self?.toggle() }
        triggers.shortcutFailed = { [weak self] in self?.model.error = L10n.text("panel.shortcutFailed") }
        triggers.configure(settings)
        settingsObserver = settings.objectWillChange.receive(on: RunLoop.main).sink { [weak self] in
            guard let self else { return }
            self.triggers.configure(self.settings)
            guard self.presentation != .hidden else { return }
            if self.settings.isPinned { self.positionPinnedPanels() }
            else if self.window?.isVisible == true { self.positionPrimary(followsPointer: false) }
        }
        pinObserver = settings.$isPinned.dropFirst().receive(on: RunLoop.main).sink { [weak self] pinned in
            guard let self, self.presentation != .hidden else { return }
            if pinned { self.pinAcrossDisplays() }
            else { self.removeSecondaryPanels(); self.primaryDisplayID = nil; self.present() }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private static func makePanel() -> NSPanel {
        WorkspaceDisplayPanel(
            contentRect: NSRect(x: 0, y: 0, width: PanelAppearance.defaultWidth, height: 700),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
    }

    private func installContent(on panel: NSPanel) {
        panel.title = L10n.text("workspace.title")
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications]
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self
        (panel as? WorkspaceDisplayPanel)?.onCancel = { [weak self] in self?.collapse() }

        let effect = PanelGlassView(frame: .zero)
        let launchTarget = WorkspaceLaunchTargetResolver { [weak panel] in
            NativeDisplayTarget(screen: panel?.screen)
        }
        let root = WorkspacePanelView(model: model, panelSettings: settings, close: { [weak self] in
            self?.collapse()
        }, settings: { [weak self] in
            self?.collapse()
            self?.openControl?()
        }).environment(\.workspaceLaunchTargetResolver, launchTarget)
        let content = NSHostingView(rootView: root)
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
    }

    func present() {
        if settings.isPinned {
            presentPinnedPanel()
            return
        }
        presentation = .overlay
        overlayWindow = window
        configureOverlay(window, on: preferredDisplay(followsPointer: true))
    }

    private func presentPinnedPanel() {
        ensurePinnedPanelsMatchDisplays()
        let targetDisplay = preferredDisplay(followsPointer: true)
        guard let panel = targetDisplay.flatMap({ panel(for: $0.id) }) ?? window else { return }
        if let previous = overlayWindow, previous !== panel {
            configureDesktop(previous, on: display(for: previous))
        }
        presentation = .overlay
        overlayWindow = panel
        configureOverlay(panel, on: targetDisplay ?? display(for: panel))
    }

    private func configureOverlay(_ panel: NSWindow?, on display: WorkspacePanelDisplay?) {
        guard let panel else { return }
        (panel as? NSPanel)?.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications]
        panel.level = .floating
        if let display { position(panel, on: display) }
        panel.makeKeyAndOrderFront(nil)
    }

    private func configureDesktop(_ panel: NSWindow?, on display: WorkspacePanelDisplay?) {
        guard let panel else { return }
        if let display { position(panel, on: display) }
        (panel as? NSPanel)?.isFloatingPanel = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        // Above the desktop icons, below every normal app window. The panel reserves only its own area.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.orderBack(nil)
    }

    private func position(_ panel: NSWindow, on display: WorkspacePanelDisplay) {
        panel.setFrame(PanelAppearance.frame(in: display.visibleFrame, width: settings.width,
                                             leftSide: settings.leftSide), display: true)
    }

    private func positionPrimary(followsPointer: Bool) {
        guard let window, let display = preferredDisplay(followsPointer: followsPointer) else { return }
        position(window, on: display)
    }

    private func positionPinnedPanels() {
        let displays = Dictionary(uniqueKeysWithValues: displayProvider().map { ($0.id, $0) })
        if let primaryDisplayID, let display = displays[primaryDisplayID], let window {
            position(window, on: display)
        }
        for (id, panel) in secondaryPanels {
            if let display = displays[id] { position(panel, on: display) }
        }
    }

    private func preferredDisplay(followsPointer: Bool) -> WorkspacePanelDisplay? {
        let displays = displayProvider()
        if followsPointer {
            // Use the display containing the pointer; do not move any other application's windows.
            let point = NSEvent.mouseLocation
            if let display = displays.first(where: { NSMouseInRect(point, $0.frame, false) }) { return display }
        }
        if let primaryDisplayID, let display = displays.first(where: { $0.id == primaryDisplayID }) { return display }
        if let window {
            let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
            if let display = displays.first(where: { NSMouseInRect(center, $0.frame, false) }) { return display }
        }
        return displays.first
    }

    private func panel(for displayID: CGDirectDisplayID) -> NSWindow? {
        if primaryDisplayID == displayID { return window }
        return secondaryPanels[displayID]
    }

    private func display(for panel: NSWindow) -> WorkspacePanelDisplay? {
        let displayID: CGDirectDisplayID?
        if panel === window { displayID = primaryDisplayID }
        else { displayID = secondaryPanels.first(where: { $0.value === panel })?.key }
        guard let displayID else { return nil }
        return displayProvider().first { $0.id == displayID }
    }

    private func ensurePinnedPanelsMatchDisplays() {
        let activeIDs = Set(displayProvider().map(\.id))
        var currentIDs = Set(secondaryPanels.keys)
        if let primaryDisplayID { currentIDs.insert(primaryDisplayID) }
        if primaryDisplayID == nil || activeIDs != currentIDs { pinAcrossDisplays() }
    }

    private func pinAcrossDisplays(preferred: WorkspacePanelDisplay? = nil) {
        guard let primaryPanel = window else { return }
        let displays = displayProvider()
        removeSecondaryPanels()
        overlayWindow = nil
        guard !displays.isEmpty else {
            primaryDisplayID = nil
            presentation = .desktop
            configureDesktop(primaryPanel, on: nil)
            return
        }
        let primaryDisplay = preferred.flatMap { preferred in
            displays.first { $0.id == preferred.id }
        } ?? preferredDisplay(followsPointer: false) ?? displays[0]
        primaryDisplayID = primaryDisplay.id
        presentation = .desktop
        configureDesktop(primaryPanel, on: primaryDisplay)
        for display in displays where display.id != primaryDisplay.id {
            let panel = panelFactory()
            installContent(on: panel)
            secondaryPanels[display.id] = panel
            configureDesktop(panel, on: display)
        }
    }

    private func removeSecondaryPanels() {
        for panel in secondaryPanels.values {
            panel.delegate = nil
            panel.orderOut(nil)
        }
        secondaryPanels.removeAll()
    }

    func toggle() {
        if presentation == .overlay, window?.isVisible == true { collapse() } else { present() }
    }

    func collapse() {
        // Set the state first: resigning key during orderOut must not restore a pinned panel.
        presentation = .hidden
        overlayWindow = nil
        window?.orderOut(nil)
        removeSecondaryPanels()
        primaryDisplayID = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        // Only display panels collapse. Editing remains in the independent control window.
        guard presentation != .hidden else { return }
        if settings.isPinned, let panel = notification.object as? NSWindow,
           panel === window || secondaryPanels.values.contains(where: { $0 === panel }) {
            configureDesktop(panel, on: display(for: panel))
            if overlayWindow === panel {
                overlayWindow = nil
                presentation = .desktop
            }
        } else if !settings.isPinned {
            collapse()
        }
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        reconcilePinnedDisplays()
    }

    func reconcilePinnedDisplays() {
        guard presentation != .hidden else { return }
        if settings.isPinned {
            let preferred = primaryDisplayID.flatMap { id in displayProvider().first { $0.id == id } }
            pinAcrossDisplays(preferred: preferred)
        } else {
            positionPrimary(followsPointer: false)
        }
    }

    func stop() {
        triggers.stop()
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        removeSecondaryPanels()
    }
}
