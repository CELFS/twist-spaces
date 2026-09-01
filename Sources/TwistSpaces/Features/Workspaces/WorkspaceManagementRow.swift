import SwiftUI

struct WorkspaceManagementRow: View {
    let workspace: Workspace
    @ObservedObject var model: WorkspaceViewModel
    @State private var confirmsDeletion = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: workspace.name).font(.headline).lineLimit(1).help(workspace.name)
                ApplicationPairView(workspace: workspace)
                if let result = model.results[workspace.id] {
                    Text(verbatim: result.message).font(.caption)
                        .foregroundStyle(result.succeeded ? Color.secondary : .orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SplitScreenPreview(leftPercentage: Double(workspace.leftPercentage),
                               leftApplication: workspace.left.application, rightApplication: workspace.right.application)
                .frame(width: 112, height: 63)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: L10n.text("workspace.ratioValue"), workspace.leftPercentage, 100 - workspace.leftPercentage))
            WorkspaceActionButtons(workspaceID: workspace.id, model: model)
            Button(L10n.text("workspace.edit")) { model.edit(workspace) }
                .disabled(model.isBusy || !model.canSave)
            IconActionButton(titleKey: "workspace.delete", symbol: "trash") {
                confirmsDeletion = true
            }
            .disabled(model.isBusy || !model.canSave)
            .confirmationDialog(
                String(format: L10n.text("workspace.deleteTitle"), workspace.name),
                isPresented: $confirmsDeletion,
                titleVisibility: .visible
            ) {
                Button(L10n.text("workspace.delete"), role: .destructive) {
                    model.deleteWorkspace(workspace)
                }
                Button(L10n.text("workspace.cancel"), role: .cancel) {}
            } message: {
                Text(L10n.text("workspace.deleteMessage"))
            }
        }
        .padding(.vertical, 8)
    }
}
