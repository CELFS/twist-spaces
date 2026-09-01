import AppKit
import SwiftUI
import Testing
@testable import TwistSpaces

private let first = SavedApplication(name: "Editor", bundleIdentifier: "test.editor", bundlePath: "/Applications/Editor.app")
private let second = SavedApplication(name: "Assistant", bundleIdentifier: "test.assistant", bundlePath: "/Applications/Assistant.app")
private func group(_ id: Int) -> Workspace {
    Workspace(id: id, name: "Group", projectPath: "", left: first.windowRecord, right: second.windowRecord)
}

@Test @MainActor func newWindowsDoNotDeduplicateAcrossGroupsOrActivateInstead() async {
    var created: [URL] = []
    var activated = 0
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { _ in activated += 1 },
                                     createWindow: { created.append($0) })
    let results = await launcher.open([group(1), group(2)], action: .newWindows)
    #expect(created.map(\.path) == [first.bundlePath, second.bundlePath, first.bundlePath, second.bundlePath])
    #expect(activated == 0)
    #expect(results == [1: .startedOrCreated, 2: .startedOrCreated])
}

@Test @MainActor func activateDoesNotCallNewWindowOperation() async {
    var created = 0
    var activated = 0
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { _ in activated += 1 },
                                     createWindow: { _ in created += 1 })
    _ = await launcher.open([group(1), group(2)], action: .activate)
    #expect(activated == 2)
    #expect(created == 0)
}

@Test @MainActor func stoppedApplicationStartsOnceWithoutExtraNewWindow() async throws {
    var launched = 0
    var created = 0
    let operation = NewWindowOperation(running: { _ in nil }, launch: { _ in launched += 1 }, create: { _ in created += 1 })
    try await operation.open(URL(fileURLWithPath: first.bundlePath))
    #expect(launched == 1)
    #expect(created == 0)
}

@Test @MainActor func runningApplicationCreatesWithoutRestartAndUnsupportedNeverFallsBack() async {
    var launched = 0
    var created = 0
    let operation = NewWindowOperation(running: { _ in
        ApplicationSnapshot(pid: 42, name: first.name, bundleIdentifier: first.bundleIdentifier, bundlePath: first.bundlePath)
    }, launch: { _ in launched += 1 }, create: { _ in created += 1; throw NewWindowError.unsupported })
    await #expect(throws: NewWindowError.unsupported) { try await operation.open(URL(fileURLWithPath: first.bundlePath)) }
    #expect(launched == 0)
    #expect(created == 1)
}

@Test @MainActor func failedCreationIsPerGroupAndNeverReportedAsSuccessful() async {
    var calls = 0
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { _ in }, createWindow: { _ in
        calls += 1
        if calls == 1 { throw NewWindowError.unconfirmed }
    })
    let results = await launcher.open([group(1), group(2)], action: .newWindows)
    #expect(results[1]?.succeeded == false)
    #expect(results[2] == .startedOrCreated)
    #expect(calls == 4)
}

@Test @MainActor func missingAppBlocksAllNewWindowRequests() async {
    var calls = 0
    let launcher = WorkspaceLauncher(resolve: { _ in throw CocoaError(.fileNoSuchFile) }, launch: { _ in },
                                     createWindow: { _ in calls += 1 })
    let results = await launcher.open([group(1)], action: .newWindows)
    #expect(calls == 0)
    #expect(results[1]?.succeeded == false)
}

@Test func newWindowCommandNeverMatchesNewFilesThreadsOrProfiles() {
    #expect(NewWindowCommand.matches("New Window"))
    #expect(NewWindowCommand.matches("新建窗口"))
    for title in ["New Text File", "New Thread", "New Chat", "New Agents Window", "New Window with Profile", "Close Window"] {
        #expect(!NewWindowCommand.matches(title))
    }
    #expect(NewWindowCommand.isStandardWindow(role: "AXWindow", subrole: "AXStandardWindow"))
    #expect(!NewWindowCommand.isStandardWindow(role: "AXWindow", subrole: "AXDialog"))
    #expect(!NewWindowCommand.isStandardWindow(role: "AXSheet", subrole: nil))
}

@Test @MainActor func ratioPersistsAndOldLibrariesDefaultToEqualSplit() throws {
    var workspace = group(1)
    workspace.leftPercentage = 65
    let data = try JSONEncoder().encode(workspace)
    #expect(try JSONDecoder().decode(Workspace.self, from: data).leftPercentage == 65)
    var old = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    old.removeValue(forKey: "leftPercentage")
    #expect(try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: old)).leftPercentage == 50)
    let draft = WorkspaceDraft(id: 1, original: workspace)
    #expect(draft.leftPercentage == 65)
    draft.leftPercentage = 35
    #expect(try draft.workspace().leftPercentage == 35)
    #expect(try draft.workspace().layout == .nativeSplitView)
    draft.leftPercentage = .nan
    #expect(!draft.canSave)
    #expect(throws: WorkspaceError.invalidWorkspace) { try draft.workspace() }
}

@Test func invalidRatioDoesNotPassLibraryValidation() {
    var workspace = group(1)
    workspace.leftPercentage = 100
    #expect(throws: WorkspaceError.invalidWorkspace) { try WorkspaceLibrary(nextID: 2, workspaces: [workspace]).validate() }
}

@Test @MainActor func selectingCombinationOnlyChangesSelection() throws {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/action-tests-\(ProcessInfo.processInfo.globallyUniqueString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = WorkspaceStore(url: directory.appendingPathComponent("workspaces.json"))
    try store.save(WorkspaceLibrary(nextID: 2, workspaces: [group(1)]))
    var calls = 0
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { _ in calls += 1 }, createWindow: { _ in calls += 1 })
    let model = WorkspaceViewModel(store: store, launcher: launcher, catalog: { [] })
    model.toggleSelection(1)
    #expect(model.selectedIDs == [1])
    model.toggleSelection(1)
    #expect(model.selectedIDs.isEmpty)
    model.toggleSelection(999)
    #expect(model.selectedIDs.isEmpty)
    #expect(calls == 0)
}

@Test @MainActor func iconActionHasLargerHitTargetThanItsGlyph() {
    let host = NSHostingView(rootView: IconActionButton(titleKey: "launch.activate", symbol: "arrow.up.forward", action: {}))
    #expect(host.fittingSize.width >= 36)
    #expect(host.fittingSize.height >= 36)
}

@Test @MainActor func singleAppOpeningNeverCallsSplitViewOrActivate() async {
    var created: [URL] = []
    var activated = 0
    var split = 0
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { _ in activated += 1 },
                                     createWindow: { created.append($0) }, openWorkspace: { _, _, _, _ in
        split += 1
        return .splitApplied(50)
    })
    #expect(await launcher.openSingleApplication(first) == .startedOrCreated)
    #expect(created.map(\.path) == [first.bundlePath])
    #expect(activated == 0 && split == 0)
}

@Test @MainActor func singleAppFailureDoesNotFallBackOrCreateAnotherWindow() async {
    var created = 0
    var activated = 0
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { _ in activated += 1 },
                                     createWindow: { _ in created += 1; throw NewWindowError.unsupported })
    #expect(await launcher.openSingleApplication(first) == .failed(NewWindowError.unsupported.localizedDescription))
    #expect(created == 1 && activated == 0)
    let missing = WorkspaceLauncher(resolve: { _ in throw CocoaError(.fileNoSuchFile) }, createWindow: { _ in created += 1 })
    #expect(await missing.openSingleApplication(first) == .failed(L10n.text("quickLaunch.applicationMissing")))
    #expect(created == 1)
}
