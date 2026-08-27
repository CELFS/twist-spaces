import Foundation
import Testing
@testable import TwistSpaces

@Test func nativeMenuNeverUsesDesktopTiling() {
    #expect(NativeSplitMenu.isLeftCommand("屏幕左侧", ancestors: ["窗口", "全屏幕拼贴"]))
    #expect(NativeSplitMenu.isLeftCommand("Left of Screen", ancestors: ["Window", "Full Screen Tile"]))
    #expect(NativeSplitMenu.isLeftCommand("Tile Window to Left of Screen", ancestors: ["Window"]))
    #expect(!NativeSplitMenu.isLeftCommand("Left of Screen", ancestors: ["Move & Resize"]))
    #expect(!NativeSplitMenu.isLeftCommand("左侧", ancestors: ["移动与调整大小"]))
    #expect(!NativeSplitMenu.isLeftCommand("屏幕右侧", ancestors: ["全屏幕拼贴"]))
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

@Test @MainActor func productionOpeningPassesRatioAndDoesNotFallBackToLaunchOnly() async {
    let first = SavedApplication(name: "Left", bundleIdentifier: "test.left", bundlePath: "/Applications/Left.app")
    let second = SavedApplication(name: "Right", bundleIdentifier: "test.right", bundlePath: "/Applications/Right.app")
    var workspace = Workspace(id: 1, name: "Pair", projectPath: "", left: first.windowRecord, right: second.windowRecord)
    workspace.leftPercentage = 65
    var ratios: [Int] = []
    var fallbackCalls = 0
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { _ in fallbackCalls += 1 },
        createWindow: { _ in fallbackCalls += 1 }, openWorkspace: { group, urls, action in
            #expect(urls.count == 2)
            #expect(action == .newWindows)
            ratios.append(group.leftPercentage)
            if group.id == 2 { throw NativeSplitError.pairUnconfirmed }
            return 65
        })
    let failed = Workspace(id: 2, name: "Pair", projectPath: "", left: first.windowRecord, right: second.windowRecord, leftPercentage: 65)
    let result = await launcher.open([workspace, failed], action: .newWindows)
    #expect(result[1] == .splitApplied(65))
    #expect(result[2]?.succeeded == false)
    #expect(ratios == [65, 65])
    #expect(fallbackCalls == 0)
}
