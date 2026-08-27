import Foundation

struct SavedWindow: Codable, Equatable, Sendable {
    let applicationName: String
    let bundleIdentifier: String
    let bundlePath: String
    let title: String
    let document: String?
    let identifier: String?

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

    enum Layout: String, Codable, Sendable {
        case nativeSplitView
    }
}

struct WorkspaceLibrary: Codable, Equatable, Sendable {
    var version = 1
    var nextID = 1
    var workspaces: [Workspace] = []

    func validate() throws {
        guard version == 1 else { throw WorkspaceError.unsupportedVersion }
        guard nextID > 0, Set(workspaces.map(\.id)).count == workspaces.count,
              workspaces.allSatisfy({ $0.id > 0 && $0.id < nextID }) else {
            throw WorkspaceError.invalidLibrary
        }
        for workspace in workspaces {
            try Self.validate(name: workspace.name, projectPath: workspace.projectPath)
            for window in [workspace.left, workspace.right] {
                guard !window.bundleIdentifier.isEmpty, window.bundlePath.hasPrefix("/") else {
                    throw WorkspaceError.invalidLibrary
                }
            }
        }
    }

    static func validate(name: String, projectPath: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              projectPath.hasPrefix("/") else { throw WorkspaceError.invalidWorkspace }
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
