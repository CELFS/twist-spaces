import AppKit

enum WorkspaceOpenAction { case activate, newWindows }

enum WorkspaceLaunchResult: Equatable {
    case opened
    case startedOrCreated
    case failed(String)
    case blocked

    var message: String {
        switch self {
        case .opened: L10n.text("launch.opened")
        case .startedOrCreated: L10n.text("launch.newCompleted")
        case .failed(let message): message
        case .blocked: L10n.text("launch.blocked")
        }
    }

    var succeeded: Bool {
        switch self {
        case .opened, .startedOrCreated: true
        case .failed, .blocked: false
        }
    }
}

@MainActor
final class WorkspaceLauncher {
    private let resolve: @MainActor (SavedApplication) throws -> URL
    private let launch: @MainActor (URL) async throws -> Void
    private let createWindow: @MainActor (URL) async throws -> Void

    init(
        resolve: @escaping @MainActor (SavedApplication) throws -> URL = WorkspaceLauncher.applicationURL,
        launch: @escaping @MainActor (URL) async throws -> Void = WorkspaceLauncher.openApplication,
        createWindow: @escaping @MainActor (URL) async throws -> Void = { try await NewWindowOperation().open($0) }
    ) {
        self.resolve = resolve
        self.launch = launch
        self.createWindow = createWindow
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
        configuration.allowsRunningApplicationSubstitution = false
        // Use normal application opening; do not invent project routes or request extra instances.
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    func open(_ workspaces: [Workspace], action: WorkspaceOpenAction = .activate) async -> [Int: WorkspaceLaunchResult] {
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
        if action == .newWindows {
            var results: [Int: WorkspaceLaunchResult] = [:]
            for workspace in workspaces {
                var failures: [String] = []
                // Each side of each group owns a request, even when groups share the same application.
                for application in workspace.applications {
                    guard let url = resolved[application.id] else { continue }
                    do { try await createWindow(url) }
                    catch { failures.append("\(application.name): \(error.localizedDescription)") }
                }
                results[workspace.id] = failures.isEmpty ? .startedOrCreated : .failed(failures.joined(separator: "\n"))
            }
            return results
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
