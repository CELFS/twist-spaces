import Foundation
import Testing
@testable import TwistSpaces

@Test func applicationAliasesAreVisibleWithoutProductSpecificRules() {
    #expect(ApplicationIdentity.displayName(primary: "ChatGPT", alternateNames: ["Codex"], language: .english) == "ChatGPT (Codex)")
    #expect(ApplicationIdentity.displayName(primary: "Editor", alternateNames: ["EDITOR", "", "Studio", "studio"], language: .english) == "Editor (Studio)")
    #expect(ApplicationIdentity.displayName(primary: "Editor", alternateNames: [], language: .english) == "Editor")
}

@Test func installedCatalogIncludesClosedAppsButNotNestedHelpers() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/catalog-tests-\(ProcessInfo.processInfo.globallyUniqueString)")
    defer { try? FileManager.default.removeItem(at: root) }
    func app(_ path: String, _ identifier: String, background: Bool = false, accessory: Bool = false) throws -> URL {
        let url = root.appendingPathComponent(path)
        let contents = url.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": identifier, "CFBundleName": "App", "CFBundlePackageType": "APPL",
                                   "LSBackgroundOnly": background, "LSUIElement": accessory]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        return url
    }
    let main = try app("Folder/Closed.app", "test.closed")
    _ = try app("Folder/Closed.app/Contents/Helpers/Helper.app", "test.nested")
    _ = try app("Background.app", "test.background", background: true)
    _ = try app("Menu.app", "test.menu", accessory: true)
    let apps = InstalledApplicationCatalog.applications(in: [root, root])
    #expect(Set(apps.map(\.bundleIdentifier)) == ["test.closed", "test.menu"])
    #expect(apps.first { $0.bundleIdentifier == "test.closed" }?.bundlePath == main.path)
}

@Test @MainActor func refreshedApplicationNamesDoNotDuplicateSavedIdentities() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/catalog-tests-\(ProcessInfo.processInfo.globallyUniqueString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let saved = SavedApplication(name: "Old", bundleIdentifier: "test.app", bundlePath: "/Applications/App.app")
    let current = SavedApplication(name: "New (Alias)", bundleIdentifier: saved.bundleIdentifier, bundlePath: saved.bundlePath)
    let otherCopy = SavedApplication(name: current.name, bundleIdentifier: saved.bundleIdentifier, bundlePath: "/Users/test/Applications/App.app")
    let store = WorkspaceStore(url: root.appendingPathComponent("workspaces.json"))
    try store.save(WorkspaceLibrary(nextID: 2, workspaces: [Workspace(id: 1, name: "Pair", projectPath: "", left: saved.windowRecord, right: saved.windowRecord)]))
    let model = WorkspaceViewModel(store: store, catalog: { [current, otherCopy] })
    model.refreshApplications()
    #expect(model.applications.count == 2)
    #expect(model.applications.first { $0.id == saved.id }?.name == current.name)
    #expect(model.library.workspaces[0].left.applicationName == "Old")
    let draft = WorkspaceDraft(id: 1, original: model.library.workspaces[0])
    draft.leftApplication = current
    #expect(try draft.workspace().left == saved.windowRecord)
}
