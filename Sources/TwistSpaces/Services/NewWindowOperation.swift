import AppKit

@MainActor
struct NewWindowOperation {
    var running: @MainActor (URL) -> ApplicationSnapshot? = { url in
        NSWorkspace.shared.runningApplications.first {
            !$0.isTerminated && $0.bundleURL?.standardizedFileURL == url.standardizedFileURL
        }.map { ApplicationSnapshot(pid: $0.processIdentifier, name: $0.localizedName ?? url.lastPathComponent,
                                   bundleIdentifier: $0.bundleIdentifier, bundlePath: $0.bundleURL?.path) }
    }
    var launch: @MainActor (URL) async throws -> Void = WorkspaceLauncher.openApplication
    var create: @MainActor (ApplicationSnapshot) async throws -> Void = { application in
        try await NewWindowService.shared.createWindow(in: application)
    }

    func open(_ url: URL) async throws {
        if let application = running(url) {
            try await create(application)
        } else {
            // A stopped app starts normally once. Do not immediately add a second startup window.
            try await launch(url)
        }
    }
}
