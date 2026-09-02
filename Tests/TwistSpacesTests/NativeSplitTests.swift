import Foundation
import Testing
@testable import TwistSpaces

@Test func nativePickerUsesObservedBackdropInsteadOfHoverLabel() {
    // macOS 15.4.1, 2026-08-28 01:48:27: exact captured target IDs remained visible.
    // The display-sized Dock backdrop was layer -1; no layer-20 window covered the preview.
    let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let left = CGRect(x: 0, y: 0, width: 718, height: 900)
    let preview = CGRect(x: 948, y: 18, width: 474, height: 548)
    #expect(NativeSplitGeometry.pickerPoint(left: left, preview: preview, display: display) == CGPoint(x: 1185, y: 292))
    #expect(NativeSplitGeometry.isPickerBackdrop(display, display: display))
    #expect(!NativeSplitGeometry.isPickerBackdrop(CGRect(x: -4, y: 0, width: 726, height: 900), display: display))
    #expect(!NativeSplitGeometry.isPickerBackdrop(CGRect(x: 1031, y: 267, width: 91, height: 30), display: display))
    // Geometry alone can pass during a transition; production also requires the new Dock backdrop and stability.
    #expect(NativeSplitGeometry.pickerPoint(left: left, preview: CGRect(x: 738, y: 24, width: 702, height: 814),
                                          display: display) != nil)
    // Do not click while the right window still spans the desktop during the transition.
    #expect(NativeSplitGeometry.pickerPoint(left: left, preview: CGRect(x: 0, y: 25, width: 1440, height: 823),
                                          display: display) == nil)
}

@Test func nativeMenuNeverUsesDesktopTiling() {
    #expect(NativeSplitMenu.isLeftCommand("屏幕左侧", ancestors: ["窗口", "全屏幕拼贴"]))
    #expect(NativeSplitMenu.isLeftCommand("Left of Screen", ancestors: ["Window", "Full Screen Tile"]))
    #expect(NativeSplitMenu.isLeftCommand("Tile Window to Left of Screen", ancestors: ["Window"]))
    #expect(!NativeSplitMenu.isLeftCommand("Left of Screen", ancestors: ["Move & Resize"]))
    #expect(!NativeSplitMenu.isLeftCommand("左侧", ancestors: ["移动与调整大小"]))
    #expect(!NativeSplitMenu.isLeftCommand("屏幕右侧", ancestors: ["全屏幕拼贴"]))
}

@Test func incompleteCreatedFullscreenTilingRequiresRollback() {
    #expect(NativeSplitRecovery.requiresRollback(didStartTiling: true, pairConfirmed: false))
    #expect(!NativeSplitRecovery.requiresRollback(didStartTiling: false, pairConfirmed: false))
    #expect(!NativeSplitRecovery.requiresRollback(didStartTiling: true, pairConfirmed: true))
    #expect(NativeSplitRecovery.shouldRestore(origin: .created, isFullscreen: true))
    #expect(!NativeSplitRecovery.shouldRestore(origin: .created, isFullscreen: false))
    #expect(!NativeSplitRecovery.shouldRestore(origin: .matched, isFullscreen: true))
}

@Test func ratioMeasuresActualWindowsExcludingNativeDivider() {
    let display = CGRect(x: -1008, y: 100, width: 1008, height: 700)
    let left = CGRect(x: -1008, y: 100, width: 650, height: 700)
    let right = CGRect(x: -350, y: 100, width: 350, height: 700)
    #expect(NativeSplitGeometry.percentage(left: left, right: right, display: display) == 65)
    #expect(NativeSplitGeometry.percentage(left: right, right: left, display: display) == nil)
    #expect(NativeSplitGeometry.percentage(left: left, right: right.offsetBy(dx: 1008, dy: 0), display: display) == nil)
    #expect(NativeSplitGeometry.percentage(left: left.insetBy(dx: 10, dy: 100), right: right, display: display) == nil)
    #expect(NativeSplitGeometry.percentage(left: left, right: right.offsetBy(dx: -30, dy: 0), display: display) == nil)
}

@Test func nativePairAllowsSeparateFullscreenToolbar() {
    // Observed 2026-08-28 02:33:47: both AXFullScreen=1, original CG IDs both visible.
    // The right app's toolbar is a separate CG window at y=0; its main window starts at y=40.
    let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let left = CGRect(x: 0, y: 0, width: 718, height: 900)
    let right = CGRect(x: 730, y: 40, width: 710, height: 860)
    #expect(NativeSplitGeometry.percentage(left: left, right: right, display: display) == 50)
    #expect(NativeSplitGeometry.percentage(left: CGRect(x: 0, y: 40, width: 718, height: 860),
                                         right: CGRect(x: 730, y: 0, width: 710, height: 900), display: display) == 50)
    let offset = CGVector(dx: -1440, dy: 200)
    #expect(NativeSplitGeometry.percentage(left: left.offsetBy(dx: offset.dx, dy: offset.dy),
                                         right: right.offsetBy(dx: offset.dx, dy: offset.dy),
                                         display: display.offsetBy(dx: offset.dx, dy: offset.dy)) == 50)
    #expect(NativeSplitGeometry.percentage(left: left,
                                         right: CGRect(x: 730, y: 100, width: 710, height: 800), display: display) == nil)
    #expect(NativeSplitGeometry.percentage(left: CGRect(x: 0, y: 0, width: 718, height: 850),
                                         right: CGRect(x: 730, y: 0, width: 710, height: 850), display: display) == nil)
    #expect(NativeSplitGeometry.percentage(left: display, right: display, display: display) == nil)
}

@Test func targetDisplayPlacementUsesGlobalCoordinatesWithoutResizing() {
    let display = CGRect(x: -1920, y: -1080, width: 1920, height: 1080)
    let window = CGRect(x: 0, y: 25, width: 1440, height: 822)
    let origin = NativeSplitGeometry.placementOrigin(window, display: display, cascade: 0)
    let placed = CGRect(origin: origin, size: window.size)
    #expect(origin == CGPoint(x: -1680, y: -951))
    #expect(placed.size == window.size)
    #expect(NativeSplitGeometry.isOnDisplay(placed, display: display))
    #expect(!NativeSplitGeometry.isOnDisplay(window, display: display))
    #expect(NativeSplitGeometry.approximatelyEqual(placed, placed.offsetBy(dx: 1, dy: -1)))
    #expect(!NativeSplitGeometry.approximatelyEqual(placed, placed.offsetBy(dx: 2, dy: 0)))
}

@Test func projectTagLaunchUsesOnlyTheProjectFoldersLastComponent() {
    let left = SavedApplication(name: "Left", bundleIdentifier: "test.left", bundlePath: "/Applications/Left.app")
    let right = SavedApplication(name: "Right", bundleIdentifier: "test.right", bundlePath: "/Applications/Right.app")
    let split = NativeSplitResult(percentage: 50, displayID: 42, leftWindowID: 101, rightWindowID: 202)
    let workspace = Workspace(id: 7, name: "A custom combination name", projectPath: "/Projects/ABC",
                              left: left.windowRecord, right: right.windowRecord)
    let launch = ProjectTagLaunch(workspace: workspace, split: split)
    #expect(launch?.workspaceID == 7)
    #expect(launch?.leftProjectName == "ABC")
    #expect(launch?.rightProjectName == "ABC")
    #expect(launch?.displayID == 42)
    #expect(launch?.leftWindowID == 101)
    #expect(launch?.rightWindowID == 202)

    let noProject = Workspace(id: 8, name: "No fallback", projectPath: "",
                              left: left.windowRecord, right: right.windowRecord)
    #expect(ProjectTagLaunch(workspace: noProject, split: split) == nil)
}

@Test func projectTagNameUsesTheWindowProjectComponentAndRejectsGenericTitles() {
    #expect(ProjectTagNameResolver.projectName(
        windowTitle: "ProjectTagController.swift — twist-spaces — Cursor", applicationName: "Cursor"
    ) == "twist-spaces")
    #expect(ProjectTagNameResolver.projectName(
        windowTitle: "● README.md – flaq.ai – Cursor", applicationName: "Cursor"
    ) == "flaq.ai")
    #expect(ProjectTagNameResolver.projectName(
        windowTitle: "Fix existing project tags — Codex", applicationName: "ChatGPT"
    ) == "Fix existing project tags")
    #expect(ProjectTagNameResolver.projectName(
        windowTitle: "Search twist-spaces — version.json — twist-spaces — Index Modified",
        applicationName: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92"
    ) == "twist-spaces")
    #expect(ProjectTagNameResolver.projectName(
        windowTitle: "Search twist-balance — notes.md — twist-balance — Untracked",
        applicationName: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92"
    ) == "twist-balance")
    #expect(ProjectTagNameResolver.projectName(windowTitle: "Cursor", applicationName: "Cursor") == nil)
    #expect(ProjectTagNameResolver.projectName(windowTitle: "  ", applicationName: "Cursor") == nil)
}

@Test func discoveredProjectTagsCanIdentifyEachSideIndependently() {
    let launch = ProjectTagLaunch(displayID: 42, leftWindowID: 101, rightWindowID: 202,
                                  leftProjectName: "ABC", rightProjectName: "XYZ")
    #expect(launch?.workspaceID == nil)
    #expect(launch?.leftProjectName == "ABC")
    #expect(launch?.rightProjectName == "XYZ")
    let codexFallback = ProjectTagLaunch(displayID: 42, leftWindowID: 101, rightWindowID: 202,
                                         leftProjectName: "ABC", rightProjectName: nil)
    #expect(codexFallback?.leftProjectName == "ABC")
    #expect(codexFallback?.rightProjectName == "ABC")
    #expect(ProjectTagLaunch(displayID: 42, leftWindowID: 101, rightWindowID: 202,
                             leftProjectName: "", rightProjectName: nil) == nil)
}

@Test @MainActor func productionOpeningPassesRatioAndDoesNotFallBackToLaunchOnly() async {
    let first = SavedApplication(name: "Left", bundleIdentifier: "test.left", bundlePath: "/Applications/Left.app")
    let second = SavedApplication(name: "Right", bundleIdentifier: "test.right", bundlePath: "/Applications/Right.app")
    var workspace = Workspace(id: 1, name: "Pair", projectPath: "", left: first.windowRecord, right: second.windowRecord)
    workspace.leftPercentage = 65
    var ratios: [Int] = []
    var targets: [NativeDisplayTarget?] = []
    var minimumAges: [TimeInterval] = []
    var progressUpdates: [WorkspaceLaunchProgress] = []
    var fallbackCalls = 0
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { _ in fallbackCalls += 1 },
        createWindow: { _ in fallbackCalls += 1 }, openWorkspace: { group, urls, action, target, minimumAge, progress, _ in
            #expect(urls.count == 2)
            #expect(action == .newWindows)
            ratios.append(group.leftPercentage)
            targets.append(target)
            minimumAges.append(minimumAge)
            if let target {
                progress?(WorkspaceLaunchProgress(workspaceName: group.name, target: target, phase: .waitingForApplications))
            }
            if group.id == 2 { throw NativeSplitError.pairUnconfirmed }
            return .splitApplied(65)
        })
    let failed = Workspace(id: 2, name: "Pair", projectPath: "", left: first.windowRecord, right: second.windowRecord, leftPercentage: 65)
    let target = NativeDisplayTarget(displayID: 42, supportsIndependentSpaces: true)
    let result = await launcher.open([workspace, failed], action: .newWindows, target: target, minimumWindowAge: 4) {
        progressUpdates.append($0)
    }
    #expect(result[1] == .splitApplied(65))
    #expect(result[2]?.succeeded == false)
    #expect(ratios == [65, 65])
    #expect(targets == [target, target])
    #expect(minimumAges == [4, 4])
    #expect(progressUpdates.map(\.phase) == [.waitingForApplications, .waitingForApplications])
    #expect(fallbackCalls == 0)
}
