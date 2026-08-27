import Combine

@MainActor
final class WorkspaceDraft: ObservableObject, Identifiable {
    let id: Int
    let original: Workspace?
    @Published var name: String
    @Published var projectPath: String
    @Published var leftApplication: SavedApplication?
    @Published var rightApplication: SavedApplication?
    @Published var leftPercentage: Double
    @Published var error: String?

    init(id: Int, original: Workspace? = nil) {
        self.id = id
        self.original = original
        name = original?.name ?? ""
        projectPath = original?.projectPath ?? ""
        leftApplication = original?.left.application
        rightApplication = original?.right.application
        leftPercentage = Double(original?.leftPercentage ?? 50)
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (projectPath.isEmpty || projectPath.hasPrefix("/"))
            && leftApplication != nil && rightApplication != nil
            && leftPercentage.isFinite && (10...90).contains(leftPercentage)
    }

    func workspace() throws -> Workspace {
        try WorkspaceLibrary.validate(name: name, projectPath: projectPath)
        guard let leftApplication, let rightApplication else { throw WorkspaceError.selectWindows }
        guard leftPercentage.isFinite, (10...90).contains(leftPercentage) else { throw WorkspaceError.invalidWorkspace }
        // Retain legacy window metadata if its application was not changed by the user.
        let left = original.flatMap { $0.left.application.id == leftApplication.id ? $0.left : nil } ?? leftApplication.windowRecord
        let right = original.flatMap { $0.right.application.id == rightApplication.id ? $0.right : nil } ?? rightApplication.windowRecord
        return Workspace(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), projectPath: projectPath,
                         left: left, right: right, layout: original?.layout ?? .nativeSplitView, leftPercentage: Int(leftPercentage.rounded()))
    }
}
