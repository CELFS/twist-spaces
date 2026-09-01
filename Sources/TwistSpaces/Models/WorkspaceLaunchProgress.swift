import Foundation

enum WorkspaceLaunchPhase: String, CaseIterable, Equatable, Sendable {
    case openingWindows
    case waitingForApplications
    case arrangingWindows
    case creatingSplit

    var messageKey: String { "launch.progress.\(rawValue)" }
}

struct WorkspaceLaunchProgress: Equatable, Sendable {
    let workspaceName: String
    let target: NativeDisplayTarget
    let phase: WorkspaceLaunchPhase

    var title: String {
        String(format: L10n.text("launch.progress.title"), workspaceName)
    }

    var message: String { L10n.text(phase.messageKey) }

    func updating(_ phase: WorkspaceLaunchPhase) -> WorkspaceLaunchProgress {
        WorkspaceLaunchProgress(workspaceName: workspaceName, target: target, phase: phase)
    }
}

typealias WorkspaceLaunchProgressHandler = @MainActor @Sendable (WorkspaceLaunchProgress) -> Void
typealias WorkspaceLaunchPhaseHandler = @MainActor @Sendable (WorkspaceLaunchPhase) -> Void
