import AppKit
import Combine

struct WorkspaceDraft: Identifiable {
    let id: Int
    var name: String
    var projectPath: String
    var leftToken: Int?
    var rightToken: Int?
    var original: Workspace?
    var confirmedPair = false
}

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var library = WorkspaceLibrary()
    @Published private(set) var windows: [WorkspaceWindow] = []
    @Published private(set) var scanIssues: [String] = []
    @Published private(set) var isBusy = false
    @Published private(set) var canSave = false
    @Published private(set) var accessibilityTrusted = AccessibilityPermission.isTrusted
    @Published var selectedIDs: Set<Int> = []
    @Published var draft: WorkspaceDraft?
    @Published var error: String?
    @Published private(set) var results: [Int: String] = [:]

    private let store: WorkspaceStore
    private let inspector = WindowInspector()
    private var bindings: [Int: (left: Int, right: Int)] = [:]
    static let codexBundleIdentifier = "com.openai.codex"

    init(store: WorkspaceStore = .standard) {
        self.store = store
        do {
            library = try store.load()
            canSave = true
        } catch {
            // A damaged or newer library is never overwritten with an empty one.
            self.error = "\(L10n.text("workspace.loadFailed"))\n\(error.localizedDescription)\n\(store.url.path)"
        }
    }

    func newWorkspace() {
        draft = WorkspaceDraft(id: library.nextID, name: "", projectPath: "")
        Task { await refreshWindows() }
    }

    func edit(_ workspace: Workspace) {
        draft = WorkspaceDraft(
            id: workspace.id, name: workspace.name, projectPath: workspace.projectPath,
            leftToken: bindings[workspace.id]?.left, rightToken: bindings[workspace.id]?.right,
            original: workspace, confirmedPair: true
        )
        Task { await refreshWindows() }
    }

    func chooseProject() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = L10n.text("workspace.chooseFolder")
        guard picker.runModal() == .OK, let url = picker.url else { return }
        draft?.projectPath = url.path
        if draft?.name.isEmpty == true { draft?.name = url.lastPathComponent }
    }

    func requestPermission() {
        AccessibilityPermission.requestFromUser()
    }

    func refreshWindows() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        accessibilityTrusted = AccessibilityPermission.isTrusted
        let applications = ApplicationCatalog.runningApplications().filter {
            $0.bundleIdentifier == CursorAccessibility.bundleIdentifier || $0.bundleIdentifier == Self.codexBundleIdentifier
        }
        let scan = await inspector.workspaceWindows(applications)
        windows = scan.windows
        scanIssues = scan.issues
        if applications.isEmpty { scanIssues.append(L10n.text("workspace.noApplications")) }
        for (identifier, key) in [(CursorAccessibility.bundleIdentifier, "workspace.cursorNotRunning"), (Self.codexBundleIdentifier, "workspace.codexNotRunning")] {
            if !applications.contains(where: { $0.bundleIdentifier == identifier }) { scanIssues.append(L10n.text(key)) }
        }
        if let token = draft?.leftToken, !windows.contains(where: { $0.id == token }) { draft?.leftToken = nil }
        if let token = draft?.rightToken, !windows.contains(where: { $0.id == token }) { draft?.rightToken = nil }
    }

    func saveDraft() {
        guard canSave, !isBusy, let draft else { return }
        do {
            try WorkspaceLibrary.validate(name: draft.name, projectPath: draft.projectPath)
            let left = windows.first { $0.id == draft.leftToken }?.saved ?? draft.original?.left
            let right = windows.first { $0.id == draft.rightToken }?.saved ?? draft.original?.right
            guard draft.confirmedPair, let left, let right,
                  draft.leftToken == nil || draft.leftToken != draft.rightToken else { throw WorkspaceError.selectWindows }
            let workspace = Workspace(
                id: draft.id, name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                projectPath: draft.projectPath, left: left, right: right
            )
            var updated = library
            if let index = updated.workspaces.firstIndex(where: { $0.id == draft.id }) {
                updated.workspaces[index] = workspace
            } else {
                updated.workspaces.append(workspace)
                updated.nextID += 1
            }
            try store.save(updated)
            library = updated
            if let leftToken = draft.leftToken, let rightToken = draft.rightToken {
                bindings[draft.id] = (leftToken, rightToken)
            } else {
                bindings[draft.id] = nil
            }
            results[draft.id] = nil
            self.draft = nil
        } catch { self.error = error.localizedDescription }
    }

    func showWindows(for ids: Set<Int>) async {
        guard !isBusy else { return }
        await refreshWindows()
        isBusy = true
        defer { isBusy = false }
        let workspaces = library.workspaces.filter { ids.contains($0.id) }
        var pairs: [(workspace: Workspace, left: Int, right: Int)] = []
        var failed = false
        for workspace in workspaces {
            do {
                let left = try WorkspaceMatcher.resolve(workspace.left, token: bindings[workspace.id]?.left, windows: windows)
                let right = try WorkspaceMatcher.resolve(workspace.right, token: bindings[workspace.id]?.right, windows: windows)
                guard left != right else { throw WorkspaceError.selectWindows }
                pairs.append((workspace, left, right))
            } catch {
                results[workspace.id] = error.localizedDescription
                failed = true
            }
        }
        // Resolve every selected workspace before the first AX write; no guessing or partial preflight.
        guard !failed else {
            for pair in pairs { results[pair.workspace.id] = L10n.text("workspace.batchBlocked") }
            return
        }
        do {
            try await inspector.showWindows(tokens: pairs.flatMap { [$0.left, $0.right] })
            for pair in pairs {
                bindings[pair.workspace.id] = (pair.left, pair.right)
                results[pair.workspace.id] = L10n.text("workspace.windowsShown")
            }
        } catch {
            for pair in pairs { results[pair.workspace.id] = error.localizedDescription }
        }
    }
}
