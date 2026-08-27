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
    #expect(draft.canSave)
    model.saveDraft(draft)
    #expect(model.draft == nil)
    #expect(draft.name == "开发组合")
    let saved = try #require(model.library.workspaces.first)
    #expect(saved.projectPath.isEmpty)
    #expect(saved.applications == [editorApp, assistantApp])
    #expect(saved.left.document == nil)
    #expect(try store.load().workspaces == [saved])
    model.edit(saved)
    let edited = try #require(model.draft)
    edited.name = "Updated"
    model.saveDraft(edited)
    #expect(try store.load().workspaces.first?.name == "Updated")
    #expect(model.library.nextID == 2)
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
        [ApplicationSnapshot(pid: 1, name: editorApp.name, bundleIdentifier: editorApp.bundleIdentifier, bundlePath: editorApp.bundlePath),
         ApplicationSnapshot(pid: 2, name: assistantApp.name, bundleIdentifier: assistantApp.bundleIdentifier, bundlePath: assistantApp.bundlePath),
         ApplicationSnapshot(pid: 3, name: editorApp.name, bundleIdentifier: editorApp.bundleIdentifier, bundlePath: editorApp.bundlePath)]
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
