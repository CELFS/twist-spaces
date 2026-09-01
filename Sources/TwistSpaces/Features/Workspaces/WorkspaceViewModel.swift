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
    @Published private(set) var launchProgress: WorkspaceLaunchProgress?
    @Published var controlTab = WorkspaceControlTab.combinations
    @Published private(set) var openingQuickLaunchID: String?
    @Published private(set) var quickLaunchOutcome: (application: SavedApplication, result: WorkspaceLaunchResult)?

    private let store: WorkspaceStore
    private let launcher: WorkspaceLauncher
    private let minimumWindowAge: @MainActor () -> TimeInterval
    private let catalog: @MainActor () -> [SavedApplication]

    init(store: WorkspaceStore = .standard, launcher: WorkspaceLauncher = .system,
         minimumWindowAge: @escaping @MainActor () -> TimeInterval = { WindowStabilityPolicy.defaultMinimumAge },
         catalog: @escaping @MainActor () -> [SavedApplication] = ApplicationCatalog.selectableApplications) {
        self.store = store
        self.launcher = launcher
        self.minimumWindowAge = minimumWindowAge
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
        choices += library.quickLaunch.addedApplications
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

    func toggleSelection(_ id: Int) {
        guard !isBusy, library.workspaces.contains(where: { $0.id == id }) else { return }
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

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

    func deleteWorkspace(_ workspace: Workspace) {
        guard canSave, !isBusy, library.workspaces.contains(where: { $0.id == workspace.id }) else { return }
        var updated = library
        updated.workspaces.removeAll { $0.id == workspace.id }
        do {
            try store.save(updated)
            library = updated
            selectedIDs.remove(workspace.id)
            results[workspace.id] = nil
            if draft?.id == workspace.id { draft = nil }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func openApplications(for ids: Set<Int>, action: WorkspaceOpenAction = .activate,
                          target: NativeDisplayTarget? = nil) async {
        guard !isBusy else { return }
        isBusy = true
        defer {
            launchProgress = nil
            isBusy = false
        }
        let workspaces = library.workspaces.filter { ids.contains($0.id) }
        let progress: WorkspaceLaunchProgressHandler?
        if action == .newWindows {
            progress = { [weak self] update in
                guard let self else { return }
                self.launchProgress = update
            }
        } else {
            progress = nil
        }
        let outcomes = await launcher.open(workspaces, action: action, target: target,
                                           minimumWindowAge: WindowStabilityPolicy.clampedMinimumAge(minimumWindowAge()),
                                           progress: progress)
        results.merge(outcomes) { _, latest in latest }
    }

    var quickLaunchApplications: [SavedApplication] {
        library.quickLaunch.visibleApplications(in: library.workspaces)
    }

    func updateQuickLaunch(_ change: (inout QuickLaunchConfiguration) -> Void) {
        guard canSave, !isBusy else { return }
        var updated = library
        change(&updated.quickLaunch)
        do {
            try store.save(updated)
            library = updated
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func browseQuickLaunchApplications() {
        guard canSave, !isBusy else { return }
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = true
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        picker.prompt = L10n.text("applications.choose")
        guard picker.runModal() == .OK else { return }
        let applications = picker.urls.compactMap { ApplicationIdentity.read(at: $0) }
        guard applications.count == picker.urls.count,
              applications.allSatisfy({ $0.bundleIdentifier != Bundle.main.bundleIdentifier }) else {
            error = L10n.text("applications.invalid")
            return
        }
        updateQuickLaunch { configuration in
            for application in applications { configuration.add(application) }
        }
        refreshApplications()
    }

    func openQuickLaunchApplication(_ application: SavedApplication) async {
        guard !isBusy, quickLaunchApplications.contains(where: { $0.id == application.id }) else { return }
        isBusy = true
        openingQuickLaunchID = application.id
        quickLaunchOutcome = nil
        defer {
            openingQuickLaunchID = nil
            isBusy = false
        }
        let result = await launcher.openSingleApplication(application)
        quickLaunchOutcome = (application, result)
    }
}
