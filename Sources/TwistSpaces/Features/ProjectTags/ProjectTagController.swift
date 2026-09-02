import AppKit
import Combine
import SwiftUI

@MainActor
final class ProjectTagController: NSObject {
    private enum Side { case left, right }

    private struct PairKey: Hashable {
        let leftWindowID: CGWindowID
        let rightWindowID: CGWindowID
    }

    private final class Session {
        var launch: ProjectTagLaunch
        var leftPanel: ProjectTagPanel?
        var rightPanel: ProjectTagPanel?
        var invalidSamples = 0
        var leftHovered = false
        var rightHovered = false

        init(launch: ProjectTagLaunch) {
            self.launch = launch
        }
    }

    private let settings: PanelSettings
    private var sessions: [PairKey: Session] = [:]
    private var settingsObserver: AnyCancellable?
    private var timer: Timer?
    private var lifecycleTicks = 0

    init(settings: PanelSettings) {
        self.settings = settings
        super.init()
        settingsObserver = Publishers.CombineLatest3(settings.$projectTagsEnabled,
                                                      settings.$projectTagHoverEnabled,
                                                      settings.$hiddenProjectTagNames)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.refreshVisibility()
                self?.updateHover()
            }
        timer = Timer.scheduledTimer(timeInterval: 0.15, target: self,
                                     selector: #selector(tick), userInfo: nil, repeats: true)
        discoverCurrentPairs()
    }

    func show(_ launch: ProjectTagLaunch) {
        upsert(launch, preferNewNames: false)
    }

    private func upsert(_ launch: ProjectTagLaunch, preferNewNames: Bool) {
        guard let screen = screen(displayID: launch.displayID) else { return }
        let key = PairKey(leftWindowID: launch.leftWindowID, rightWindowID: launch.rightWindowID)
        if let session = sessions[key] {
            let merged = session.launch.merging(launch, preferUpdateNames: preferNewNames)
            session.invalidSamples = 0
            guard merged != session.launch else {
                updateVisibility(session)
                return
            }
            closePanels(session)
            session.launch = merged
            createPanels(session, screen: screen)
            updateVisibility(session)
            return
        }
        let session = Session(launch: launch)
        createPanels(session, screen: screen)
        sessions[key] = session
        updateVisibility(session)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for session in sessions.values { close(session) }
        sessions.removeAll()
    }

    @objc private func tick() {
        updateHover()
        lifecycleTicks += 1
        if lifecycleTicks.isMultiple(of: 4) { validateSessions() }
        if lifecycleTicks >= 10 {
            lifecycleTicks = 0
            discoverCurrentPairs()
        }
    }

    private func discoverCurrentPairs() {
        for pair in ProjectTagWindowDiscovery.currentPairs() {
            upsert(pair, preferNewNames: true)
        }
    }

    private func createPanels(_ session: Session, screen: NSScreen) {
        if let projectName = session.launch.leftProjectName {
            session.leftPanel = makePanel(projectName: projectName, screen: screen, side: .left)
        }
        if let projectName = session.launch.rightProjectName {
            session.rightPanel = makePanel(projectName: projectName, screen: screen, side: .right)
        }
    }

    private func makePanel(projectName: String, screen: NSScreen, side: Side) -> ProjectTagPanel {
        let host = NSHostingView(rootView: ProjectTagView(projectName: projectName))
        let fitting = host.fittingSize
        let size = NSSize(width: min(max(fitting.width, 72), 280), height: 30)
        host.frame = NSRect(origin: .zero, size: size)
        let panel = ProjectTagPanel(contentView: host)
        panel.setFrame(panelFrame(size: size, screen: screen, side: side), display: false)
        panel.alphaValue = 0.25
        return panel
    }

    private func panelFrame(size: NSSize, screen: NSScreen, side: Side) -> NSRect {
        let horizontalMargin: CGFloat = 18
        let topMargin: CGFloat = 16
        let x = side == .left ? screen.frame.minX + horizontalMargin : screen.frame.maxX - horizontalMargin - size.width
        return NSRect(x: x, y: screen.frame.maxY - topMargin - size.height,
                      width: size.width, height: size.height)
    }

    private func refreshVisibility() {
        for session in sessions.values { updateVisibility(session) }
    }

    private func updateVisibility(_ session: Session) {
        updateVisibility(session.leftPanel, projectName: session.launch.leftProjectName)
        updateVisibility(session.rightPanel, projectName: session.launch.rightProjectName)
    }

    private func updateVisibility(_ panel: ProjectTagPanel?, projectName: String?) {
        guard let panel, let projectName else { return }
        if settings.projectTagsEnabled && !settings.hidesProjectTag(named: projectName) {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func updateHover() {
        let pointer = NSEvent.mouseLocation
        for session in sessions.values {
            if let panel = session.leftPanel {
                setHovered(settings.projectTagHoverEnabled && panel.frame.contains(pointer),
                           panel: panel, current: &session.leftHovered)
            }
            if let panel = session.rightPanel {
                setHovered(settings.projectTagHoverEnabled && panel.frame.contains(pointer),
                           panel: panel, current: &session.rightHovered)
            }
        }
    }

    private func setHovered(_ hovered: Bool, panel: ProjectTagPanel, current: inout Bool) {
        guard current != hovered else { return }
        current = hovered
        panel.animator().alphaValue = hovered ? 0.9 : 0.25
    }

    private func validateSessions() {
        let entries = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let entriesByID = Dictionary(uniqueKeysWithValues: entries.compactMap { entry -> (CGWindowID, [String: Any])? in
            guard let id = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value else { return nil }
            return (id, entry)
        })
        var expired: [PairKey] = []
        for (key, session) in sessions {
            let valid = screen(displayID: session.launch.displayID) != nil
                && pairIsValid(session.launch, entriesByID: entriesByID)
            session.invalidSamples = valid ? 0 : session.invalidSamples + 1
            if session.invalidSamples >= 3 { expired.append(key) }
        }
        for key in expired {
            if let session = sessions.removeValue(forKey: key) { close(session) }
        }
    }

    private func pairIsValid(_ launch: ProjectTagLaunch,
                             entriesByID: [CGWindowID: [String: Any]]) -> Bool {
        guard let left = entriesByID[launch.leftWindowID].flatMap(windowBounds),
              let right = entriesByID[launch.rightWindowID].flatMap(windowBounds) else { return false }
        return NativeSplitGeometry.percentage(left: left, right: right,
                                              display: CGDisplayBounds(launch.displayID)) != nil
    }

    private func windowBounds(_ entry: [String: Any]) -> CGRect? {
        guard let dictionary = entry[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary)
    }

    private func screen(displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }
    }

    private func close(_ session: Session) {
        closePanels(session)
    }

    private func closePanels(_ session: Session) {
        for panel in [session.leftPanel, session.rightPanel].compactMap({ $0 }) {
            panel.orderOut(nil)
            panel.close()
        }
        session.leftPanel = nil
        session.rightPanel = nil
    }
}
