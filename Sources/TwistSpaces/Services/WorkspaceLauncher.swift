import AppKit

enum WorkspaceLaunchResult: Equatable {
    case opened
    case failed(String)
    case blocked

    var message: String {
        switch self {
        case .opened: L10n.text("launch.opened")
        case .failed(let message): message
        case .blocked: L10n.text("launch.blocked")
        }
    }

    var succeeded: Bool {
        if case .opened = self { return true }
        return false
    }
}

@MainActor
final class WorkspaceLauncher {
    private let resolve: @MainActor (SavedApplication) throws -> URL
    private let launch: @MainActor (URL) async throws -> Void

    init(
        resolve: @escaping @MainActor (SavedApplication) throws -> URL = WorkspaceLauncher.applicationURL,
        launch: @escaping @MainActor (URL) async throws -> Void = WorkspaceLauncher.openApplication
    ) {
        self.resolve = resolve
        self.launch = launch
    }

    static func applicationURL(_ application: SavedApplication) throws -> URL {
        let url = URL(fileURLWithPath: application.bundlePath)
        guard url.pathExtension == "app", let bundle = Bundle(url: url),
              bundle.bundleIdentifier == application.bundleIdentifier,
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }

    static func openApplication(_ url: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        // Use normal application opening; do not invent project routes or request extra instances.
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    func open(_ workspaces: [Workspace]) async -> [Int: WorkspaceLaunchResult] {
        var resolved: [String: URL] = [:]
        var applications: [SavedApplication] = []
        var errors: [String: String] = [:]
        for application in workspaces.flatMap(\.applications) where !applications.contains(where: { $0.id == application.id }) {
            applications.append(application)
            do { resolved[application.id] = try resolve(application) }
            catch { errors[application.id] = "\(application.name): \(L10n.text("launch.applicationMissing"))" }
        }
        // Resolve every selected workspace before the first application launch.
        // An unresolved application blocks the batch without opening an unrelated replacement.
        if !errors.isEmpty {
            return Dictionary(uniqueKeysWithValues: workspaces.map { workspace in
                let messages = workspace.applications.compactMap { errors[$0.id] }
                return (workspace.id, messages.isEmpty ? .blocked : .failed(messages.joined(separator: "\n")))
            })
        }
        for application in applications {
            guard let url = resolved[application.id] else { continue }
            do { try await launch(url) }
            catch { errors[application.id] = "\(application.name): \(error.localizedDescription)" }
        }
        return Dictionary(uniqueKeysWithValues: workspaces.map { workspace in
            let messages = workspace.applications.compactMap { errors[$0.id] }
            return (workspace.id, messages.isEmpty ? .opened : .failed(messages.joined(separator: "\n")))
        })
    }
}
