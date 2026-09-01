import SwiftUI

struct WorkspaceActionButtons: View {
    let workspaceID: Int
    @ObservedObject var model: WorkspaceViewModel
    @Environment(\.workspaceLaunchTargetResolver) private var launchTarget

    var body: some View {
        HStack(spacing: 4) {
            IconActionButton(titleKey: "launch.activate", symbol: "arrow.up.forward") {
                let target = launchTarget.resolve()
                Task { await model.openApplications(for: [workspaceID], action: .activate, target: target) }
            }
            IconActionButton(titleKey: "launch.newWindows", symbol: "plus.rectangle.on.rectangle") {
                let target = launchTarget.resolve()
                Task { await model.openApplications(for: [workspaceID], action: .newWindows, target: target) }
            }
        }
        .disabled(model.isBusy)
    }
}
