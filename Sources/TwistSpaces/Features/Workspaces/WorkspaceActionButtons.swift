import SwiftUI

struct WorkspaceActionButtons: View {
    let workspaceID: Int
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        HStack(spacing: 4) {
            IconActionButton(titleKey: "launch.activate", symbol: "arrow.up.forward") {
                Task { await model.openApplications(for: [workspaceID], action: .activate) }
            }
            IconActionButton(titleKey: "launch.newWindows", symbol: "plus.rectangle.on.rectangle") {
                Task { await model.openApplications(for: [workspaceID], action: .newWindows) }
            }
        }
        .disabled(model.isBusy)
    }
}
