import Foundation
import Testing
@testable import TwistSpaces

private func sampleWindow(title: String = "project", document: String? = nil, bundle: String = "example.editor") -> SavedWindow {
    SavedWindow(applicationName: "Editor", bundleIdentifier: bundle, bundlePath: "/Applications/Editor.app", title: title, document: document, identifier: nil)
}

private func sampleLibrary() -> WorkspaceLibrary {
    WorkspaceLibrary(nextID: 2, workspaces: [Workspace(id: 1, name: "项目 Café", projectPath: "/Projects/Café", left: sampleWindow(), right: sampleWindow(bundle: "example.assistant"))])
}

@Test func workspaceRoundTripPreservesProjectAndNativeLayout() throws {
    let original = sampleLibrary()
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(WorkspaceLibrary.self, from: data)
    #expect(decoded == original)
    #expect(decoded.workspaces[0].layout == .nativeSplitView)
    let json = String(decoding: data, as: UTF8.self)
    #expect(!json.contains("pid"))
    #expect(!json.contains("ordinal"))
    #expect(!json.contains("Token"))
}

@Test func workspaceValidationRejectsInvalidIDsAndFutureVersions() {
    var library = sampleLibrary()
    library.version = 2
    #expect(throws: WorkspaceError.unsupportedVersion) { try library.validate() }
    library.version = 1
    library.workspaces.append(library.workspaces[0])
    #expect(throws: WorkspaceError.invalidLibrary) { try library.validate() }
    library = sampleLibrary()
    library.nextID = 1
    #expect(throws: WorkspaceError.invalidLibrary) { try library.validate() }
    #expect(throws: WorkspaceError.invalidWorkspace) { try WorkspaceLibrary.validate(name: "  ", projectPath: "/Projects") }
    #expect(throws: WorkspaceError.invalidWorkspace) { try WorkspaceLibrary.validate(name: "Name", projectPath: "relative") }
}

@Test func liveWindowUsesExactSessionToken() throws {
    let saved = sampleWindow()
    let windows = [WorkspaceWindow(id: 4, saved: saved), WorkspaceWindow(id: 5, saved: saved)]
    #expect(try WorkspaceMatcher.resolve(saved, token: 5, windows: windows) == 5)
}

@Test func titleOnlyNeverMatchesAfterRestartOrWindowDisappearance() {
    let saved = sampleWindow()
    let windows = [WorkspaceWindow(id: 5, saved: saved)]
    #expect(throws: WorkspaceError.reselectWindow) { try WorkspaceMatcher.resolve(saved, token: nil, windows: windows) }
    #expect(throws: WorkspaceError.reselectWindow) { try WorkspaceMatcher.resolve(saved, token: 4, windows: windows) }
}

@Test func changedTitleDoesNotReuseSessionWindow() {
    let windows = [WorkspaceWindow(id: 4, saved: sampleWindow(title: "another project"))]
    #expect(throws: WorkspaceError.reselectWindow) { try WorkspaceMatcher.resolve(sampleWindow(), token: 4, windows: windows) }
}

@Test func exactDocumentIdentityMustBeUniqueAndInSameApplication() throws {
    let saved = sampleWindow(document: "file:///Projects/Cafe")
    let candidate = WorkspaceWindow(id: 8, saved: saved)
    #expect(try WorkspaceMatcher.resolve(saved, token: nil, windows: [candidate]) == 8)
    #expect(throws: WorkspaceError.ambiguousWindow) {
        try WorkspaceMatcher.resolve(saved, token: nil, windows: [candidate, WorkspaceWindow(id: 9, saved: saved)])
    }
    let otherApp = WorkspaceWindow(id: 10, saved: sampleWindow(document: "file:///Projects/Cafe", bundle: "example.other"))
    #expect(throws: WorkspaceError.windowUnavailable) { try WorkspaceMatcher.resolve(saved, token: nil, windows: [otherApp]) }
}

@Test func storePersistsEditsAndProtectsInvalidLibrary() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent(".build/workspace-tests-\(ProcessInfo.processInfo.globallyUniqueString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = WorkspaceStore(url: directory.appendingPathComponent("workspaces.json"))
    #expect(try store.load() == WorkspaceLibrary())
    var library = sampleLibrary()
    try store.save(library)
    #expect(try store.load() == library)
    library.workspaces[0].name = "Updated"
    try store.save(library)
    #expect(try store.load().workspaces[0].name == "Updated")
    let before = try Data(contentsOf: store.url)
    library.version = 2
    #expect(throws: WorkspaceError.unsupportedVersion) { try store.save(library) }
    #expect(try Data(contentsOf: store.url) == before)
    try Data("invalid".utf8).write(to: store.url)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: store.url) == Data("invalid".utf8))
}

@Test @MainActor func unreadableStoreDisablesSavingInsteadOfReplacingUserData() {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let model = WorkspaceViewModel(store: WorkspaceStore(url: root))
    #expect(!model.canSave)
    #expect(model.error != nil)
}

@Test func workspaceLocalizationDoesNotClaimSplitViewWasApplied() {
    #expect(L10n.text("workspace.windowsShown", language: .english).contains("not applied"))
    #expect(L10n.text("workspace.openBoundary", language: .english).contains("not implemented"))
    #expect(L10n.text("workspace.new", language: .english) == "New combination")
}
