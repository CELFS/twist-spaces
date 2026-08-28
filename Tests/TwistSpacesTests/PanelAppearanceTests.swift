import AppKit
import SwiftUI
import Testing
@testable import TwistSpaces

@MainActor private final class PanelCloseRecorder: NSPanel {
    var collapseCount = 0
    var recordedVisible = false
    var frontCount = 0
    var desktopCount = 0
    override var isVisible: Bool { recordedVisible }
    override func makeKeyAndOrderFront(_ sender: Any?) { recordedVisible = true; frontCount += 1 }
    override func orderBack(_ sender: Any?) { recordedVisible = true; desktopCount += 1 }
    override func orderOut(_ sender: Any?) { recordedVisible = false; collapseCount += 1 }
}

@MainActor private final class ControlWindowPresentationRecorder: NSWindow {
    var displayedSize: CGSize?
    var centeredSizes: [CGSize] = []

    override func makeKeyAndOrderFront(_ sender: Any?) {
        if let displayedSize { setContentSize(displayedSize) }
    }

    override func center() {
        centeredSizes.append(frame.size)
        super.center()
    }
}

@Test @MainActor func controlWindowCentersAfterDisplayAndOnEveryReopening() throws {
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/control-position-\(ProcessInfo.processInfo.globallyUniqueString)")
    let model = WorkspaceViewModel(store: WorkspaceStore(url: directory.appendingPathComponent("workspaces.json")), catalog: { [] })
    let controller = WorkspaceControlController(model: model, settings: PanelSettings(defaults: defaults), showPanel: {})
    let window = ControlWindowPresentationRecorder(contentRect: CGRect(x: 0, y: 0, width: 740, height: 540),
                                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
    controller.window = window
    window.displayedSize = CGSize(width: 620, height: 420)
    controller.present()
    let firstFrame = window.frame
    #expect(window.centeredSizes == [firstFrame.size])
    #expect(window.contentRect(forFrameRect: firstFrame).width == 620)
    let screen = try #require(window.screen)
    #expect(abs(firstFrame.midX - screen.visibleFrame.midX) < 1)
    window.displayedSize = nil
    window.setFrameOrigin(CGPoint(x: firstFrame.minX + 100, y: firstFrame.minY))
    controller.present()
    #expect(window.centeredSizes.count == 2)
    #expect(window.frame == firstFrame)
}

@Test @MainActor func hostedControlWindowRemainsCenteredAfterLayout() async throws {
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/control-position-\(ProcessInfo.processInfo.globallyUniqueString)")
    let model = WorkspaceViewModel(store: WorkspaceStore(url: directory.appendingPathComponent("workspaces.json")), catalog: { [] })
    let controller = WorkspaceControlController(model: model, settings: PanelSettings(defaults: defaults), showPanel: {})
    let window = try #require(controller.window)
    defer { window.close() }
    controller.present()
    let presentedFrame = window.frame
    // The real hosting controller can update the window after present() returns.
    try await Task.sleep(for: .milliseconds(150))
    let screen = try #require(window.screen)
    #expect(window.frame == presentedFrame)
    #expect(abs(window.frame.midX - screen.visibleFrame.midX) < 1)
    #expect(screen.visibleFrame.contains(window.frame))

    window.setContentSize(NSSize(width: 860, height: 560))
    try await Task.sleep(for: .milliseconds(150))
    let resizedSize = window.frame.size
    window.setFrameOrigin(CGPoint(x: screen.visibleFrame.maxX - resizedSize.width, y: screen.visibleFrame.minY))
    window.close()
    controller.present()
    try await Task.sleep(for: .milliseconds(150))
    #expect(window.frame.size == resizedSize)
    #expect(abs(window.frame.midX - screen.visibleFrame.midX) < 1)
    #expect(screen.visibleFrame.contains(window.frame))
}

@Test @MainActor func pinnedPanelReturnsToDesktopAndCanBeTemporarilyRevealed() async throws {
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/panel-pin-\(ProcessInfo.processInfo.globallyUniqueString)")
    let settings = PanelSettings(defaults: defaults)
    let model = WorkspaceViewModel(store: WorkspaceStore(url: directory.appendingPathComponent("workspaces.json")), catalog: { [] })
    let controller = WorkspacePanelController(model: model, settings: settings)
    defer { controller.stop() }
    let displayPanel = try #require(controller.window as? WorkspaceDisplayPanel)
    let window = PanelCloseRecorder(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
    controller.window = window
    let notification = Notification(name: NSWindow.didResignKeyNotification, object: window)
    controller.present()
    #expect(window.level == .floating)
    controller.windowDidResignKey(notification)
    #expect(window.collapseCount == 1)
    #expect(!window.isVisible)

    controller.present()
    settings.isPinned = true
    try await Task.sleep(for: .milliseconds(30))
    #expect(window.level.rawValue == Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    #expect(window.level.rawValue < NSWindow.Level.normal.rawValue)
    #expect(!window.isFloatingPanel)
    #expect(window.collectionBehavior.contains(.stationary))
    #expect(!window.collectionBehavior.contains(.fullScreenAuxiliary))
    #expect(!window.collectionBehavior.contains(.canJoinAllApplications))
    #expect(window.isVisible)

    // The menu/shortcut raises a desktop resident instead of treating it as an open overlay to hide.
    let previousFrontCount = window.frontCount
    controller.toggle()
    #expect(window.frontCount == previousFrontCount + 1)
    #expect(window.level == .floating)
    #expect(window.isFloatingPanel)
    #expect(window.collectionBehavior.contains(.fullScreenAuxiliary))
    #expect(window.collectionBehavior.contains(.canJoinAllApplications))
    controller.windowDidResignKey(notification)
    #expect(window.collapseCount == 1)
    #expect(window.level.rawValue < NSWindow.Level.normal.rawValue)
    #expect(window.isVisible)

    // The edge trigger uses present(), including when the pinned desktop panel is already visible.
    controller.present()
    #expect(window.level == .floating)
    controller.windowDidResignKey(notification)
    #expect(window.level.rawValue < NSWindow.Level.normal.rawValue)

    controller.collapse()
    let desktopCount = window.desktopCount
    controller.windowDidResignKey(notification)
    #expect(window.desktopCount == desktopCount)
    #expect(!window.isVisible)
    controller.toggle()
    #expect(window.isVisible)
    #expect(window.level == .floating)
    #expect(settings.isPinned)

    displayPanel.cancelOperation(nil)
    controller.windowDidResignKey(notification)
    #expect(!window.isVisible)
    #expect(settings.isPinned)

    controller.present()
    controller.windowDidResignKey(notification)
    settings.isPinned = false
    try await Task.sleep(for: .milliseconds(30))
    #expect(window.level == .floating)
    controller.windowDidResignKey(notification)
    #expect(window.collapseCount == 4)
    settings.isPinned = true
    try await Task.sleep(for: .milliseconds(30))
    #expect(!window.isVisible)
    #expect(!PanelSettings(defaults: defaults).isPinned)
}

@Test func screenRatioDraggingUsesTheScreenInteriorAndFivePercentSteps() {
    #expect(SplitRatioInteraction.dividerPosition(percentage: 50, width: 412) == 206)
    #expect(SplitRatioInteraction.draggedPercentage(start: 50, translation: 0, width: 412) == 50)
    #expect(SplitRatioInteraction.draggedPercentage(start: 50, translation: 9, width: 412) == 50)
    #expect(SplitRatioInteraction.draggedPercentage(start: 50, translation: 11, width: 412) == 55)
    #expect(SplitRatioInteraction.draggedPercentage(start: 50, translation: -60, width: 412) == 35)
    #expect(SplitRatioInteraction.draggedPercentage(start: 50, translation: -1000, width: 412) == 10)
    #expect(SplitRatioInteraction.draggedPercentage(start: 50, translation: 1000, width: 412) == 90)
    #expect(SplitRatioInteraction.draggedPercentage(start: 50, translation: 1000, width: 0) == 50)
}

@Test @MainActor func splitScreenPreviewAndEditorFitTheirAvailableWidths() throws {
    let left = SavedApplication(name: "Safari", bundleIdentifier: "com.apple.Safari", bundlePath: "/Applications/Safari.app")
    let right = SavedApplication(name: "TextEdit", bundleIdentifier: "com.apple.TextEdit", bundlePath: "/System/Applications/TextEdit.app")
    let draft = WorkspaceDraft(id: 1)
    draft.leftApplication = left
    draft.rightApplication = right
    let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/split-ratio-previews")

    func check<V: View>(_ view: V, width: Double, name: String) throws {
        let host = NSHostingView(rootView: view.frame(width: width).fixedSize(horizontal: false, vertical: true)
            .padding(16).background(Color(nsColor: .windowBackgroundColor)))
        #expect(abs(host.fittingSize.width - width - 32) < 0.001)
        #expect(host.fittingSize.height > 50)
        guard ProcessInfo.processInfo.environment["TWIST_SPLIT_RATIO_PREVIEWS"] == "1" else { return }
        host.setFrameSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("\(name).png"))
    }

    for percentage in [10, 50, 65, 90] {
        for width in [110.0, 240.0] {
            try check(SplitRatioPreview(leftPercentage: percentage, leftApplication: left, rightApplication: right),
                      width: width, name: "preview-\(percentage)-\(Int(width))")
        }
        draft.leftPercentage = Double(percentage)
        try check(WorkspaceRatioEditor(draft: draft), width: 472, name: "editor-\(percentage)")
    }
    draft.leftApplication = nil
    draft.rightApplication = nil
    try check(WorkspaceRatioEditor(draft: draft), width: 472, name: "editor-no-apps")
    for dragging in [false, true] {
        try check(SplitScreenPreview(leftPercentage: 50, leftApplication: left, rightApplication: right,
                                     showsDividerHandle: true, dividerHovered: true, dividerDragging: dragging)
            .frame(width: 360, height: 202.5), width: 472, name: dragging ? "divider-dragging" : "divider-hover")
    }

    let model = WorkspaceViewModel(store: WorkspaceStore(url: output.appendingPathComponent("unused-workspaces.json")), catalog: { [left, right] })
    draft.leftApplication = left
    draft.rightApplication = right
    draft.leftPercentage = 50
    draft.name = "Example combination"
    // Measure the complete sheet without fixedSize, which can hide compression during AppKit's fitting pass.
    let sheet = NSHostingView(rootView: WorkspaceEditorView(model: model, draft: draft)
        .background(Color(nsColor: .windowBackgroundColor)))
    #expect(abs(sheet.fittingSize.width - 520) < 0.001)
    #expect(sheet.fittingSize.height > 450)
    if ProcessInfo.processInfo.environment["TWIST_SPLIT_RATIO_PREVIEWS"] == "1" {
        sheet.setFrameSize(sheet.fittingSize)
        sheet.layoutSubtreeIfNeeded()
        let bitmap = try #require(sheet.bitmapImageRepForCachingDisplay(in: sheet.bounds))
        sheet.cacheDisplay(in: sheet.bounds, to: bitmap)
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("complete-editor.png"))
    }
}

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
    model.controlTab = .combinations
    for width in [572.0, 692.0] {
        for percentage in [10, 50, 90] {
            var rowWorkspace = group
            rowWorkspace.leftPercentage = percentage
            let row = WorkspaceManagementRow(workspace: rowWorkspace, model: model)
                .frame(width: width).fixedSize(horizontal: false, vertical: true)
            let host = NSHostingView(rootView: row)
            #expect(abs(host.fittingSize.width - width) < 0.001)
            #expect(host.fittingSize.height <= 90)
            try preview(row.padding(16).background(Color(nsColor: .windowBackgroundColor)),
                        name: "combination-row-\(Int(width))-\(percentage)")
        }
    }
    try preview(WorkspaceControlView(model: model, settings: settings, showPanel: {})
        .frame(width: 801, height: 540).background(Color(nsColor: .windowBackgroundColor)), name: "combinations")
    model.controlTab = .quickLaunch
    try preview(WorkspaceControlView(model: model, settings: settings, showPanel: {})
        .frame(width: 801, height: 540).background(Color(nsColor: .windowBackgroundColor)), name: "management")
    model.controlTab = .display
    try preview(WorkspaceControlView(model: model, settings: settings, showPanel: {})
        .frame(width: 801, height: 540).background(Color(nsColor: .windowBackgroundColor)), name: "display")
}
