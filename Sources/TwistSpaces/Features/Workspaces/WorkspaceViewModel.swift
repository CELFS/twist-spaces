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
    private let catalog: @MainActor () -> [ApplicationSnapshot]

    init(store: WorkspaceStore = .standard, launcher: WorkspaceLauncher = WorkspaceLauncher(),
         catalog: @escaping @MainActor () -> [ApplicationSnapshot] = ApplicationCatalog.runningApplications) {
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
        var choices = library.workspaces.flatMap(\.applications)
        choices += [draft?.leftApplication, draft?.rightApplication].compactMap { $0 }
        choices += catalog().compactMap { app in
            guard let bundleIdentifier = app.bundleIdentifier, let bundlePath = app.bundlePath,
                  bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
            return SavedApplication(name: app.name, bundleIdentifier: bundleIdentifier, bundlePath: bundlePath)
        }
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
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else {
            draft.error = L10n.text("applications.invalid")
            return
        }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent
        let application = SavedApplication(name: name, bundleIdentifier: identifier, bundlePath: url.path)
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
