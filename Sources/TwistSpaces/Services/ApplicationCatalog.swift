import AppKit

@MainActor
enum ApplicationCatalog {
    static func selectableApplications() -> [SavedApplication] {
        let installed = InstalledApplicationCatalog.applications(in: InstalledApplicationCatalog.directories)
        let running = NSWorkspace.shared.runningApplications.compactMap { app -> SavedApplication? in
            // Installed menu-bar apps are already included above; do not add OS agents as applications.
            guard !app.isTerminated, app.activationPolicy == .regular, let url = app.bundleURL,
                  !url.path.contains(".app/Contents/") else { return nil }
            return ApplicationIdentity.read(at: url, runningName: app.localizedName)
        }
        var seen = Set<String>()
        return (installed + running).filter { seen.insert($0.id).inserted }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func runningApplications() -> [ApplicationSnapshot] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .map { app in
                ApplicationSnapshot(
                    pid: app.processIdentifier,
                    name: app.bundleURL.flatMap { ApplicationIdentity.read(at: $0, runningName: app.localizedName)?.name }
                        ?? app.localizedName ?? app.bundleIdentifier ?? String(app.processIdentifier),
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
