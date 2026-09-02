import CoreGraphics
import Foundation

struct ProjectTagLaunch: Equatable, Sendable {
    let workspaceID: Int?
    let leftProjectName: String?
    let rightProjectName: String?
    let displayID: CGDirectDisplayID
    let leftWindowID: CGWindowID
    let rightWindowID: CGWindowID

    init?(workspace: Workspace, split: NativeSplitResult) {
        let path = workspace.projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        let projectName = URL(fileURLWithPath: path).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectName.isEmpty else { return nil }
        workspaceID = workspace.id
        leftProjectName = projectName
        rightProjectName = projectName
        displayID = split.displayID
        leftWindowID = split.leftWindowID
        rightWindowID = split.rightWindowID
    }

    init?(displayID: CGDirectDisplayID, leftWindowID: CGWindowID, rightWindowID: CGWindowID,
          leftProjectName: String?, rightProjectName: String?) {
        let left = Self.normalized(leftProjectName)
        let right = Self.normalized(rightProjectName)
        guard left != nil || right != nil else { return nil }
        workspaceID = nil
        self.leftProjectName = left
        self.rightProjectName = right
        self.displayID = displayID
        self.leftWindowID = leftWindowID
        self.rightWindowID = rightWindowID
    }

    func merging(_ update: ProjectTagLaunch, preferUpdateNames: Bool) -> ProjectTagLaunch {
        let left = preferUpdateNames
            ? update.leftProjectName ?? leftProjectName
            : leftProjectName ?? update.leftProjectName
        let right = preferUpdateNames
            ? update.rightProjectName ?? rightProjectName
            : rightProjectName ?? update.rightProjectName
        return ProjectTagLaunch(workspaceID: workspaceID ?? update.workspaceID,
                                leftProjectName: left, rightProjectName: right,
                                displayID: update.displayID,
                                leftWindowID: update.leftWindowID, rightWindowID: update.rightWindowID)
    }

    private init(workspaceID: Int?, leftProjectName: String?, rightProjectName: String?,
                 displayID: CGDirectDisplayID, leftWindowID: CGWindowID, rightWindowID: CGWindowID) {
        self.workspaceID = workspaceID
        self.leftProjectName = leftProjectName
        self.rightProjectName = rightProjectName
        self.displayID = displayID
        self.leftWindowID = leftWindowID
        self.rightWindowID = rightWindowID
    }

    private static func normalized(_ name: String?) -> String? {
        guard let name else { return nil }
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

typealias ProjectTagLaunchHandler = @MainActor @Sendable (ProjectTagLaunch) -> Void
