import AppKit
import SwiftUI
import Testing
@testable import TwistSpaces

@Test func panelLeavesSpaceAroundEitherScreenEdge() {
    let screen = CGRect(x: -1920, y: 40, width: 1920, height: 1000)
    for left in [true, false] {
        let frame = PanelAppearance.frame(in: screen, width: 340, leftSide: left)
        #expect(frame.width == 340)
        #expect(frame.minY == screen.minY + 12)
        #expect(frame.maxY == screen.maxY - 12)
        #expect(left ? frame.minX == screen.minX + 12 : frame.maxX == screen.maxX - 12)
    }
}

@Test func panelFitsSmallDisplaysWithoutLosingItsMargin() {
    let screen = CGRect(x: 80, y: -500, width: 320, height: 400)
    let frame = PanelAppearance.frame(in: screen, width: 700, leftSide: false)
    #expect(frame.width == 296)
    #expect(frame.minX == 92)
    #expect(frame.maxX == 388)
    #expect(screen.contains(frame))
}

@Test @MainActor func restoredDefaultMigratesOnlyOnceAndKeepsOtherSettings() throws {
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(340, forKey: "panel.displayWidth")
    defaults.set(true, forKey: "panel.edgeEnabled")
    let settings = PanelSettings(defaults: defaults)
    #expect(settings.width == 460)
    #expect(settings.edgeEnabled)
    settings.width = 340
    #expect(PanelSettings(defaults: defaults).width == 340)
}

@Test @MainActor func customWidthIsPreservedAndFreshDefaultsAre460Points() throws {
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(PanelSettings(defaults: defaults).width == 460)
    defaults.removeObject(forKey: "panel.displayWidth")
    defaults.set(520, forKey: "panel.width")
    #expect(PanelSettings(defaults: defaults).width == 520)
}

@Test @MainActor func sharedPickerDoesNotFillItsParentWidth() {
    let picker = AppPicker(titleKey: "panel.side", selection: .constant(false), width: .compact) {
        Text("Left").tag(true)
        Text("Right").tag(false)
    }
    let host = NSHostingView(rootView: picker)
    #expect(host.fittingSize.width == AppFormLayout.contentInset + AppPickerWidth.compact.rawValue)
}

@Test @MainActor func nativeGlassKeepsFullBackdropOpacityAndRoundedMask() {
    let view = PanelGlassView(frame: CGRect(x: 0, y: 0, width: 460, height: 700))
    #expect(view.alphaValue == 1)
    #expect(view.material == .hudWindow)
    #expect(view.blendingMode == .behindWindow)
    #expect(view.state == .active)
    #expect(view.maskImage != nil)
    #expect(PanelAppearance.defaultWidth == 460)
}

@Test @MainActor func quickLaunchDisplayPreferencesPersistBothExpandedAndCollapsedStates() throws {
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = PanelSettings(defaults: defaults)
    #expect(!settings.quickLaunchExpanded && !settings.quickLaunchShowNames)
    settings.quickLaunchExpanded = true
    settings.quickLaunchShowNames = true
    let expanded = PanelSettings(defaults: defaults)
    #expect(expanded.quickLaunchExpanded && expanded.quickLaunchShowNames)
    expanded.quickLaunchExpanded = false
    expanded.quickLaunchShowNames = false
    let collapsed = PanelSettings(defaults: defaults)
    #expect(!collapsed.quickLaunchExpanded && !collapsed.quickLaunchShowNames)
}

@Test(arguments: [260.0, 420.0, 660.0]) func quickLaunchCollapsedModeContainsExactlyOneAdaptiveRow(width: Double) {
    let applications = (0..<30).map { SavedApplication(name: "App \($0)", bundleIdentifier: "test.app\($0)", bundlePath: "/Apps/\($0).app") }
    for showNames in [false, true] {
        let columns = QuickLaunchLayout.columnCount(width: width, showNames: showNames)
        let minimumWidth = showNames ? 88.0 : 52.0
        #expect(Double(columns) * minimumWidth + Double(columns - 1) * QuickLaunchLayout.spacing <= width)
        #expect(Double(columns + 1) * minimumWidth + Double(columns) * QuickLaunchLayout.spacing > width)
        #expect(QuickLaunchLayout.displayedApplications(applications, width: width, showNames: showNames, expanded: false) == Array(applications.prefix(columns)))
        #expect(QuickLaunchLayout.displayedApplications(applications, width: width, showNames: showNames, expanded: true) == applications)
        #expect(QuickLaunchLayout.displayedApplications([], width: width, showNames: showNames, expanded: false).isEmpty)
    }
    #expect(QuickLaunchLayout.columnCount(width: 0, showNames: true) == 1)
}

@Test @MainActor func quickLaunchRenderedRowsFitNarrowAndWidePanels() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent(".build/quick-launch-layout-\(ProcessInfo.processInfo.globallyUniqueString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = PanelSettings(defaults: defaults)
    let applications = (0..<12).map {
        SavedApplication(name: "Application \($0 + 1)", bundleIdentifier: "test.app\($0)", bundlePath: "/Applications/Example\($0).app")
    }
    let group = Workspace(id: 1, name: "Example combination", projectPath: "", left: applications[0].windowRecord, right: applications[1].windowRecord)
    let store = WorkspaceStore(url: directory.appendingPathComponent("workspaces.json"))
    try store.save(WorkspaceLibrary(nextID: 2, workspaces: [group], quickLaunch: QuickLaunchConfiguration(addedApplications: applications)))
    let model = WorkspaceViewModel(store: store, catalog: { applications })

    func preview<V: View>(_ view: V, name: String) throws {
        guard ProcessInfo.processInfo.environment["TWIST_QUICK_LAUNCH_PREVIEWS"] == "1" else { return }
        let host = NSHostingView(rootView: view)
        host.setFrameSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let output = root.appendingPathComponent(".build/quick-launch-previews")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("\(name).png"))
    }

    for width in [260.0, 420.0, 660.0] {
        for showNames in [false, true] {
            for expanded in [false, true] {
                settings.quickLaunchShowNames = showNames
                settings.quickLaunchExpanded = expanded
                let view = QuickLaunchSection(model: model, settings: settings, availableWidth: width, manage: {})
                    .frame(width: width).fixedSize(horizontal: false, vertical: true)
                let host = NSHostingView(rootView: view)
                let columns = QuickLaunchLayout.columnCount(width: width, showNames: showNames)
                let rows = expanded ? Int(ceil(Double(applications.count) / Double(columns))) : 1
                let expectedHeight = 36.0 + 8.0 + Double(rows) * (showNames ? 76.0 : 52.0) + Double(rows - 1) * 8.0
                #expect(abs(host.fittingSize.height - expectedHeight) <= 1)
                #expect(abs(host.fittingSize.width - width) < 0.001)
                if width == 260 || width == 420 {
                    try preview(view.padding(20).background(Color(nsColor: .windowBackgroundColor)),
                                name: "section-\(Int(width))-names-\(showNames)-expanded-\(expanded)")
                }
            }
        }
    }
    settings.quickLaunchExpanded = false
    settings.quickLaunchShowNames = false
    try preview(WorkspacePanelView(model: model, panelSettings: settings, close: {}, settings: {})
        .frame(width: 460, height: 700).background(Color(nsColor: .windowBackgroundColor)), name: "panel")
    model.controlTab = .quickLaunch
    try preview(WorkspaceControlView(model: model, settings: settings, showPanel: {})
        .frame(width: 620, height: 540).background(Color(nsColor: .windowBackgroundColor)), name: "management")
}
