import AppKit
import SwiftUI
import Testing
@testable import TwistSpaces

private func fixtureDirectory() -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/interaction-tests-\(ProcessInfo.processInfo.globallyUniqueString)")
}

private let editorApp = SavedApplication(name: "Editor", bundleIdentifier: "test.editor", bundlePath: "/Applications/Editor.app")
private let assistantApp = SavedApplication(name: "Assistant", bundleIdentifier: "test.assistant", bundlePath: "/Applications/Assistant.app")

@MainActor private final class QuickLaunchModelReference {
    weak var value: WorkspaceViewModel?
}

@Test @MainActor func controlCursorTracksDisabledStateAndDoesNotResetAnotherControl() {
    let original = NSCursor.current
    let first = AppControlCursor()
    let second = AppControlCursor()
    defer { first.deactivate(); second.deactivate(); original.set() }
    NSCursor.arrow.set()

    #expect(!first.update(isInside: true, isEnabled: false))
    #expect(NSCursor.current == .arrow)
    #expect(first.update(isInside: true, isEnabled: true))
    #expect(NSCursor.current == .pointingHand)
    #expect(!first.update(isInside: true, isEnabled: false))
    #expect(NSCursor.current == .arrow)
    #expect(first.update(isInside: true, isEnabled: true))
    #expect(second.update(isInside: true, isEnabled: true))
    first.deactivate()
    #expect(NSCursor.current == .pointingHand)
    #expect(!second.update(isInside: false, isEnabled: true))
    #expect(NSCursor.current == .arrow)

    for nativeCursor in [NSCursor.iBeam, .openHand, .closedHand] {
        first.update(isInside: true, isEnabled: true)
        nativeCursor.set()
        first.deactivate()
        #expect(NSCursor.current == nativeCursor)
    }
}

@Test @MainActor func editorBindingsSurviveRepeatedDismissalAndCannotChangeNextDraft() throws {
    let directory = fixtureDirectory()
    let model = WorkspaceViewModel(store: WorkspaceStore(url: directory.appendingPathComponent("workspaces.json")), catalog: { [] })
    for _ in 0..<50 {
        model.newWorkspace()
        let draft = try #require(model.draft)
        draft.name = "First"
        let retainedBinding = ObservedObject(wrappedValue: draft).projectedValue.name
        model.dismissEditor()
        // SwiftUI can still read this binding while the sheet's closing animation is running.
        #expect(retainedBinding.wrappedValue == "First")
        model.newWorkspace()
        retainedBinding.wrappedValue = "Old editor callback"
        #expect(model.draft?.name == "")
        #expect(model.draft !== draft)
        model.dismissEditor()
    }
}

@Test @MainActor func combinationsSaveAndEditWithoutAnyWindowScan() throws {
    let directory = fixtureDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = WorkspaceStore(url: directory.appendingPathComponent("workspaces.json"))
    let model = WorkspaceViewModel(store: store, catalog: { [] })
    model.newWorkspace()
    let draft = try #require(model.draft)
    draft.name = "开发组合"
    draft.leftApplication = editorApp
    draft.rightApplication = assistantApp
    draft.leftPercentage = SplitRatioInteraction.draggedPercentage(start: 50, translation: 60, width: 412)
    #expect(draft.canSave)
    model.saveDraft(draft)
    #expect(model.draft == nil)
    #expect(draft.name == "开发组合")
    let saved = try #require(model.library.workspaces.first)
    #expect(saved.projectPath.isEmpty)
    #expect(saved.applications == [editorApp, assistantApp])
    #expect(saved.leftPercentage == 65)
    #expect(saved.left.document == nil)
    #expect(try store.load().workspaces == [saved])
    model.edit(saved)
    let edited = try #require(model.draft)
    edited.name = "Updated"
    model.saveDraft(edited)
    #expect(try store.load().workspaces.first?.name == "Updated")
    #expect(model.library.nextID == 2)
    model.edit(try #require(model.library.workspaces.first))
    let cancelled = try #require(model.draft)
    cancelled.leftPercentage = SplitRatioInteraction.draggedPercentage(start: 65, translation: -100, width: 412)
    model.dismissEditor()
    #expect(try store.load().workspaces.first?.leftPercentage == 65)
}

@Test @MainActor func savingFailureKeepsDraftAndExistingInMemoryLibrary() throws {
    let directory = fixtureDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocked = directory.appendingPathComponent("blocked")
    let model = WorkspaceViewModel(store: WorkspaceStore(url: blocked.appendingPathComponent("workspaces.json")), catalog: { [] })
    try Data("not a directory".utf8).write(to: blocked)
    model.newWorkspace()
    let draft = try #require(model.draft)
    draft.name = "Cannot save"
    draft.leftApplication = editorApp
    draft.rightApplication = assistantApp
    model.saveDraft(draft)
    #expect(model.draft === draft)
    #expect(draft.error != nil)
    #expect(model.library.workspaces.isEmpty)
}

@Test @MainActor func legacyWindowMetadataSurvivesApplicationLevelEditing() throws {
    let left = SavedWindow(applicationName: editorApp.name, bundleIdentifier: editorApp.bundleIdentifier, bundlePath: editorApp.bundlePath,
                           title: "Original", document: "file:///Projects/Original", identifier: "saved-identifier")
    let workspace = Workspace(id: 1, name: "Original", projectPath: "/Projects/Original", left: left, right: assistantApp.windowRecord)
    let draft = WorkspaceDraft(id: 1, original: workspace)
    draft.name = "Renamed"
    let updated = try draft.workspace()
    #expect(updated.left == left)
    #expect(updated.projectPath == workspace.projectPath)
    #expect(updated.layout == .nativeSplitView)
}

@Test @MainActor func applicationListIncludesMoreThanCursorAndCodexAndDeduplicatesProcesses() {
    let directory = fixtureDirectory()
    let model = WorkspaceViewModel(store: WorkspaceStore(url: directory.appendingPathComponent("workspaces.json")), catalog: {
        [editorApp, assistantApp, editorApp]
    })
    model.refreshApplications()
    #expect(model.applications.count == 2)
    #expect(Set(model.applications) == [editorApp, assistantApp])
}

@Test @MainActor func batchOpeningInvokesRealLaunchBoundaryOncePerApplication() async {
    let one = Workspace(id: 1, name: "One", projectPath: "", left: editorApp.windowRecord, right: assistantApp.windowRecord)
    let two = Workspace(id: 2, name: "Two", projectPath: "", left: assistantApp.windowRecord, right: editorApp.windowRecord)
    var opened: [URL] = []
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { opened.append($0) })
    let results = await launcher.open([one, two])
    #expect(opened.map(\.path) == [editorApp.bundlePath, assistantApp.bundlePath])
    #expect(results == [1: .opened, 2: .opened])
}

@Test @MainActor func missingApplicationBlocksBatchBeforeAnyLaunch() async {
    let workspace = Workspace(id: 1, name: "One", projectPath: "", left: editorApp.windowRecord, right: assistantApp.windowRecord)
    var launches = 0
    let launcher = WorkspaceLauncher(resolve: { app in
        if app == assistantApp { throw CocoaError(.fileNoSuchFile) }
        return URL(fileURLWithPath: app.bundlePath)
    }, launch: { _ in launches += 1 })
    let results = await launcher.open([workspace])
    #expect(launches == 0)
    #expect(results[1]?.succeeded == false)
}

@Test @MainActor func launchFailureIsNotReportedAsSuccessfulOpening() async {
    let workspace = Workspace(id: 1, name: "One", projectPath: "", left: editorApp.windowRecord, right: assistantApp.windowRecord)
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, launch: { _ in throw CocoaError(.executableNotLoadable) })
    let results = await launcher.open([workspace])
    #expect(results[1]?.succeeded == false)
}

@Test func bothLanguagesHaveIdenticalKeysAndPlaceholders() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/TwistSpaces/Resources")
    func table(_ language: String) throws -> [String: String] {
        let data = try Data(contentsOf: root.appendingPathComponent("\(language).lproj/Localizable.strings"))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }
    let english = try table("en")
    let chinese = try table("zh-Hans")
    #expect(Set(english.keys) == Set(chinese.keys))
    let placeholders = try NSRegularExpression(pattern: "%[0-9.]*[df@]")
    for (key, text) in english {
        let translation = try #require(chinese[key])
        func tokens(_ value: String) -> [String] {
            placeholders.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { (value as NSString).substring(with: $0.range) }
        }
        #expect(tokens(text) == tokens(translation))
    }
    #expect(L10n.text("control.title", language: .simplifiedChinese) == "控制中心")
    #expect(L10n.text("control.title", language: .english) == "Control Center")
    #expect(L10n.text("test.missing.key", language: .simplifiedChinese) == "test.missing.key")
}

@Test func quickLaunchMergesGroupsBeforeManualAppsAndKeepsDistinctInstallations() {
    let otherEditor = SavedApplication(name: "Editor", bundleIdentifier: editorApp.bundleIdentifier, bundlePath: "/Other/Editor.app")
    let manualApp = SavedApplication(name: "Browser", bundleIdentifier: "test.browser", bundlePath: "/Applications/Browser.app")
    let groups = [Workspace(id: 1, name: "One", projectPath: "", left: editorApp.windowRecord, right: assistantApp.windowRecord),
                  Workspace(id: 2, name: "Two", projectPath: "", left: assistantApp.windowRecord, right: otherEditor.windowRecord)]
    var configuration = QuickLaunchConfiguration()
    configuration.add(manualApp)
    configuration.add(editorApp)
    configuration.add(manualApp)
    #expect(configuration.applications(in: groups) == [editorApp, assistantApp, otherEditor, manualApp])
    configuration.setVisible(false, id: assistantApp.id)
    #expect(configuration.visibleApplications(in: groups) == [editorApp, otherEditor, manualApp])
    configuration.move(manualApp.id, by: -1, in: groups)
    #expect(configuration.visibleApplications(in: groups) == [editorApp, manualApp, otherEditor])
    configuration.setVisible(true, id: assistantApp.id)
    #expect(configuration.visibleApplications(in: groups) == [editorApp, assistantApp, manualApp, otherEditor])
    configuration.removeManualApplication(editorApp.id)
    #expect(configuration.visibleApplications(in: groups).contains(editorApp))
    #expect(configuration.visibleApplications(in: []) == [manualApp])
    configuration.removeManualApplication(manualApp.id)
    #expect(configuration.visibleApplications(in: []).isEmpty)
}

@Test @MainActor func quickLaunchCustomizationsSurviveRelaunchAndCombinationEdits() throws {
    let directory = fixtureDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = WorkspaceStore(url: directory.appendingPathComponent("workspaces.json"))
    let group = Workspace(id: 1, name: "One", projectPath: "", left: editorApp.windowRecord, right: assistantApp.windowRecord)
    try store.save(WorkspaceLibrary(nextID: 2, workspaces: [group]))
    let model = WorkspaceViewModel(store: store, catalog: { [] })
    model.updateQuickLaunch {
        $0.add(editorApp)
        $0.setVisible(false, id: assistantApp.id)
        $0.move(assistantApp.id, by: -1, in: [group])
    }
    #expect(model.library.workspaces == [group])
    let restored = WorkspaceViewModel(store: store, catalog: { [] })
    #expect(restored.library.quickLaunch == model.library.quickLaunch)
    #expect(restored.quickLaunchApplications == [editorApp])
    restored.edit(group)
    let draft = try #require(restored.draft)
    draft.rightApplication = editorApp
    restored.saveDraft(draft)
    #expect(restored.library.quickLaunch.hiddenApplicationIDs.contains(assistantApp.id))
    restored.edit(try #require(restored.library.workspaces.first))
    let nextDraft = try #require(restored.draft)
    nextDraft.rightApplication = assistantApp
    restored.saveDraft(nextDraft)
    #expect(restored.quickLaunchApplications == [editorApp])
    restored.updateQuickLaunch { $0.add(assistantApp) }
    #expect(restored.quickLaunchApplications == [assistantApp, editorApp])
    #expect(try store.load().quickLaunch == restored.library.quickLaunch)
}

@Test @MainActor func quickLaunchWorksWithoutGroupsAndBlocksReentrantLaunches() async throws {
    let directory = fixtureDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let reference = QuickLaunchModelReference()
    var opened: [URL] = []
    let launcher = WorkspaceLauncher(resolve: { URL(fileURLWithPath: $0.bundlePath) }, createWindow: { url in
        opened.append(url)
        let current = try #require(reference.value)
        #expect(current.isBusy)
        #expect(current.openingQuickLaunchID == editorApp.id)
        await current.openQuickLaunchApplication(assistantApp)
        current.updateQuickLaunch { $0.setVisible(false, id: editorApp.id) }
        #expect(current.quickLaunchApplications == [editorApp, assistantApp])
    })
    let current = WorkspaceViewModel(store: WorkspaceStore(url: directory.appendingPathComponent("workspaces.json")), launcher: launcher, catalog: { [] })
    reference.value = current
    current.updateQuickLaunch { $0.add(editorApp); $0.add(assistantApp) }
    current.refreshApplications()
    #expect(Set(current.applications) == [editorApp, assistantApp])
    await current.openQuickLaunchApplication(editorApp)
    #expect(opened.map(\.path) == [editorApp.bundlePath])
    #expect(current.quickLaunchOutcome?.result == .startedOrCreated)
    #expect(!current.isBusy)
    #expect(current.openingQuickLaunchID == nil)
    #expect(current.results.isEmpty && current.selectedIDs.isEmpty && current.library.workspaces.isEmpty)
    current.updateQuickLaunch { $0.setVisible(false, id: assistantApp.id) }
    await current.openQuickLaunchApplication(assistantApp)
    #expect(opened.count == 1)
}

@Test @MainActor func quickLaunchSaveFailureKeepsConfigurationAndDamagedLibraryIsNeverReplaced() throws {
    let directory = fixtureDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocked = directory.appendingPathComponent("blocked")
    let model = WorkspaceViewModel(store: WorkspaceStore(url: blocked.appendingPathComponent("workspaces.json")), catalog: { [] })
    try Data("not a directory".utf8).write(to: blocked)
    model.updateQuickLaunch { $0.add(editorApp) }
    #expect(model.quickLaunchApplications.isEmpty)
    #expect(model.error != nil)
    let damaged = WorkspaceViewModel(store: WorkspaceStore(url: blocked), catalog: { [] })
    damaged.updateQuickLaunch { $0.add(editorApp) }
    #expect(!damaged.canSave)
    #expect(try Data(contentsOf: blocked) == Data("not a directory".utf8))
}
