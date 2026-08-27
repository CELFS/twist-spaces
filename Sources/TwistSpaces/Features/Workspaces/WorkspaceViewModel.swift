import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var library = WorkspaceLibrary()
    @Published private(set) var applications: [SavedApplication] = []
    @Published private(set) var isBusy = false
    @Published private(set) var canSave = false
    @Published var selectedIDs: Set<Int> = []
    @Published var draft: WorkspaceDraft?
    @Published var error: String?
    @Published private(set) var results: [Int: WorkspaceLaunchResult] = [:]

    private let store: WorkspaceStore
    private let launcher: WorkspaceLauncher
    private let catalog: @MainActor () -> [SavedApplication]

    init(store: WorkspaceStore = .standard, launcher: WorkspaceLauncher = WorkspaceLauncher(),
         catalog: @escaping @MainActor () -> [SavedApplication] = ApplicationCatalog.selectableApplications) {
        self.store = store
        self.launcher = launcher
        self.catalog = catalog
        do {
            library = try store.load()
            canSave = true
        } catch {
            // A damaged or newer library is never overwritten with an empty one.
            self.error = "\(L10n.text("workspace.loadFailed"))\n\(error.localizedDescription)\n\(store.url.path)"
        }
    }

    func newWorkspace() {
        refreshApplications()
        draft = WorkspaceDraft(id: library.nextID)
    }

    func edit(_ workspace: Workspace) {
        refreshApplications()
        draft = WorkspaceDraft(id: workspace.id, original: workspace)
    }

    func chooseProject(for draft: WorkspaceDraft) {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = L10n.text("workspace.chooseFolder")
        guard picker.runModal() == .OK, let url = picker.url else { return }
        draft.projectPath = url.path
        if draft.name.isEmpty { draft.name = url.lastPathComponent }
    }

    func refreshApplications() {
        // Fresh metadata takes priority over a saved display name; identity is still bundle ID + path.
        var choices = catalog().filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
        choices += library.workspaces.flatMap(\.applications)
        choices += [draft?.leftApplication, draft?.rightApplication].compactMap { $0 }
        var seen = Set<String>()
        applications = choices.filter { seen.insert($0.id).inserted }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func chooseApplication(for draft: WorkspaceDraft, left: Bool) {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = false
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        picker.prompt = L10n.text("applications.choose")
        guard picker.runModal() == .OK, let url = picker.url else { return }
        guard let application = ApplicationIdentity.read(at: url) else {
            draft.error = L10n.text("applications.invalid")
            return
        }
        if left { draft.leftApplication = application } else { draft.rightApplication = application }
        refreshApplications()
    }

    func dismissEditor() { draft = nil }

    func saveDraft(_ draft: WorkspaceDraft) {
        guard canSave, !isBusy, self.draft === draft else { return }
        do {
            let workspace = try draft.workspace()
            var updated = library
            if let index = updated.workspaces.firstIndex(where: { $0.id == draft.id }) {
                updated.workspaces[index] = workspace
            } else {
                updated.workspaces.append(workspace)
                updated.nextID += 1
            }
            try store.save(updated)
            library = updated
            results[draft.id] = nil
            self.draft = nil
        } catch { draft.error = error.localizedDescription }
    }

    func openApplications(for ids: Set<Int>) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let workspaces = library.workspaces.filter { ids.contains($0.id) }
        let outcomes = await launcher.open(workspaces)
        results.merge(outcomes) { _, latest in latest }
    }
}
