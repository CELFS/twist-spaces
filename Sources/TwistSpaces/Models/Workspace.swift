import Foundation

struct SavedApplication: Codable, Identifiable, Equatable, Hashable, Sendable {
    let name: String
    let bundleIdentifier: String
    let bundlePath: String

    var id: String { "\(bundleIdentifier)@\(bundlePath)" }

    var windowRecord: SavedWindow {
        SavedWindow(applicationName: name, bundleIdentifier: bundleIdentifier, bundlePath: bundlePath,
                    title: "", document: nil, identifier: nil)
    }
}

struct SavedWindow: Codable, Equatable, Sendable {
    let applicationName: String
    let bundleIdentifier: String
    let bundlePath: String
    let title: String
    let document: String?
    let identifier: String?

    var application: SavedApplication {
        SavedApplication(name: applicationName, bundleIdentifier: bundleIdentifier, bundlePath: bundlePath)
    }

    func matches(_ other: SavedWindow) -> Bool {
        bundleIdentifier == other.bundleIdentifier && bundlePath == other.bundlePath
            && title == other.title && document == other.document && identifier == other.identifier
    }
}

struct Workspace: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    var name: String
    var projectPath: String
    var left: SavedWindow
    var right: SavedWindow
    // Store the requested layout, never substitute ordinary desktop tiling.
    var layout: Layout = .nativeSplitView
    var leftPercentage: Int = 50

    init(id: Int, name: String, projectPath: String, left: SavedWindow, right: SavedWindow,
         layout: Layout = .nativeSplitView, leftPercentage: Int = 50) {
        self.id = id
        self.name = name
        self.projectPath = projectPath
        self.left = left
        self.right = right
        self.layout = layout
        self.leftPercentage = leftPercentage
    }

    private enum CodingKeys: String, CodingKey { case id, name, projectPath, left, right, layout, leftPercentage }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        projectPath = try values.decode(String.self, forKey: .projectPath)
        left = try values.decode(SavedWindow.self, forKey: .left)
        right = try values.decode(SavedWindow.self, forKey: .right)
        layout = try values.decodeIfPresent(Layout.self, forKey: .layout) ?? .nativeSplitView
        // Existing libraries have no ratio field; retain their equal split without rewriting them.
        leftPercentage = try values.decodeIfPresent(Int.self, forKey: .leftPercentage) ?? 50
    }

    // Keep the version-one window records intact; application opening uses only their app identities.
    var applications: [SavedApplication] { [left.application, right.application] }

    enum Layout: String, Codable, Sendable {
        case nativeSplitView
    }
}

struct WorkspaceLibrary: Codable, Equatable, Sendable {
    var version = 1
    var nextID = 1
    var workspaces: [Workspace] = []
    var quickLaunch = QuickLaunchConfiguration()

    init(version: Int = 1, nextID: Int = 1, workspaces: [Workspace] = [], quickLaunch: QuickLaunchConfiguration = .init()) {
        self.version = version
        self.nextID = nextID
        self.workspaces = workspaces
        self.quickLaunch = quickLaunch
    }

    private enum CodingKeys: String, CodingKey { case version, nextID, workspaces, quickLaunch }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        nextID = try values.decode(Int.self, forKey: .nextID)
        workspaces = try values.decode([Workspace].self, forKey: .workspaces)
        // Older libraries acquire the automatic app list without a migration or rewrite on load.
        quickLaunch = try values.decodeIfPresent(QuickLaunchConfiguration.self, forKey: .quickLaunch) ?? .init()
    }

    func validate() throws {
        guard version == 1 else { throw WorkspaceError.unsupportedVersion }
        try quickLaunch.validate()
        guard nextID > 0, nextID < Int.max, Set(workspaces.map(\.id)).count == workspaces.count,
              workspaces.allSatisfy({ $0.id > 0 && $0.id < nextID }) else {
            throw WorkspaceError.invalidLibrary
        }
        for workspace in workspaces {
            try Self.validate(name: workspace.name, projectPath: workspace.projectPath)
            guard (10...90).contains(workspace.leftPercentage) else { throw WorkspaceError.invalidWorkspace }
            for window in [workspace.left, workspace.right] {
                guard !window.bundleIdentifier.isEmpty, window.bundlePath.hasPrefix("/") else {
                    throw WorkspaceError.invalidLibrary
                }
            }
        }
    }

    static func validate(name: String, projectPath: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              projectPath.isEmpty || projectPath.hasPrefix("/") else { throw WorkspaceError.invalidWorkspace }
    }
}

struct WorkspaceWindow: Identifiable, Sendable {
    // Session-only token backed by an AX element, not an ordinal or a saved process ID.
    let id: Int
    let saved: SavedWindow
}

struct WindowScan: Sendable {
    let windows: [WorkspaceWindow]
    let issues: [String]
}

enum WorkspaceError: String, LocalizedError {
    case unsupportedVersion, invalidLibrary, invalidWorkspace, selectWindows
    case permissionRequired, windowUnavailable, ambiguousWindow, reselectWindow, windowOperationFailed

    var errorDescription: String? { L10n.text("workspace.error.\(rawValue)") }
}

enum WorkspaceMatcher {
    static func resolve(_ saved: SavedWindow, token: Int?, windows: [WorkspaceWindow]) throws -> Int {
        if let token, let window = windows.first(where: { $0.id == token }), saved.matches(window.saved) {
            return token
        }
        // A title (even a unique title) or AXIdentifier alone is not a persistent project identity.
        guard let document = saved.document, !document.isEmpty else { throw WorkspaceError.reselectWindow }
        let matches = windows.filter { saved.matches($0.saved) }
        guard matches.count <= 1 else { throw WorkspaceError.ambiguousWindow }
        guard let match = matches.first else { throw WorkspaceError.windowUnavailable }
        return match.id
    }
}
