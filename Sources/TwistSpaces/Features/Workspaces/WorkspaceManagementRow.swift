import SwiftUI

struct WorkspaceManagementRow: View {
    let workspace: Workspace
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: workspace.name).font(.headline)
                ApplicationPairView(workspace: workspace)
                SplitRatioPreview(leftPercentage: workspace.leftPercentage)
                if let result = model.results[workspace.id] {
                    Text(verbatim: result.message).font(.caption)
                        .foregroundStyle(result.succeeded ? Color.secondary : .orange)
                }
            }
            Spacer()
            WorkspaceActionButtons(workspaceID: workspace.id, model: model)
            Button(L10n.text("workspace.edit")) { model.edit(workspace) }
                .disabled(model.isBusy || !model.canSave)
        }
        .padding(.vertical, 12)
    }
}
