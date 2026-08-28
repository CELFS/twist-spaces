import Foundation

struct QuickLaunchConfiguration: Codable, Equatable, Sendable {
    var addedApplications: [SavedApplication] = []
    var hiddenApplicationIDs: Set<String> = []
    var orderedApplicationIDs: [String] = []

    func applications(in workspaces: [Workspace]) -> [SavedApplication] {
        // Group order is the default; manual additions follow it. Identity includes the app path.
        var seen = Set<String>()
        let applications = (workspaces.flatMap(\.applications) + addedApplications).filter { seen.insert($0.id).inserted }
        let byID = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0) })
        let orderedIDs = Set(orderedApplicationIDs)
        return orderedApplicationIDs.compactMap { byID[$0] } + applications.filter { !orderedIDs.contains($0.id) }
    }

    func visibleApplications(in workspaces: [Workspace]) -> [SavedApplication] {
        applications(in: workspaces).filter { !hiddenApplicationIDs.contains($0.id) }
    }

    mutating func add(_ application: SavedApplication) {
        if !addedApplications.contains(where: { $0.id == application.id }) { addedApplications.append(application) }
        hiddenApplicationIDs.remove(application.id)
    }

    mutating func setVisible(_ visible: Bool, id: String) {
        if visible { hiddenApplicationIDs.remove(id) } else { hiddenApplicationIDs.insert(id) }
    }

    mutating func removeManualApplication(_ id: String) {
        addedApplications.removeAll { $0.id == id }
        // Keep visibility and ordering preferences if this app also belongs to a group.
    }

    mutating func move(_ id: String, by offset: Int, in workspaces: [Workspace]) {
        var ids = applications(in: workspaces).map(\.id)
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + offset) else { return }
        ids.swapAt(index, index + offset)
        orderedApplicationIDs = ids
    }

    func validate() throws {
        guard Set(addedApplications.map(\.id)).count == addedApplications.count,
              Set(orderedApplicationIDs).count == orderedApplicationIDs.count,
              addedApplications.allSatisfy({ !$0.bundleIdentifier.isEmpty && $0.bundlePath.hasPrefix("/") }) else {
            throw WorkspaceError.invalidLibrary
        }
    }
}
