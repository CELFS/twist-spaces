import AppKit

@MainActor
enum ApplicationCatalog {
    static func runningApplications() -> [ApplicationSnapshot] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .map { app in
                ApplicationSnapshot(
                    pid: app.processIdentifier,
                    name: app.localizedName ?? app.bundleIdentifier ?? String(app.processIdentifier),
                    bundleIdentifier: app.bundleIdentifier,
                    bundlePath: app.bundleURL?.path
                )
            }
            .sorted {
                let order = $0.name.localizedStandardCompare($1.name)
                return order == .orderedSame ? $0.pid < $1.pid : order == .orderedAscending
            }
    }
}
