import SwiftUI

struct WorkspaceCardView: View {
    let workspace: Workspace
    @ObservedObject var model: WorkspaceViewModel
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button { model.toggleSelection(workspace.id) } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.selectedIDs.contains(workspace.id) ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundStyle(model.selectedIDs.contains(workspace.id) ? Color.accentColor : Color.secondary)
                        .frame(width: 32, height: 36)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(verbatim: workspace.name).font(.headline).lineLimit(1)
                            Spacer(minLength: 0)
                            if let result = model.results[workspace.id] {
                                Image(systemName: result.succeeded ? "checkmark" : "exclamationmark.circle")
                                    .foregroundStyle(result.succeeded ? Color.secondary : .orange)
                                    .help(result.message)
                            }
                        }
                        ApplicationPairView(workspace: workspace)
                        SplitRatioPreview(leftPercentage: workspace.leftPercentage,
                                          leftApplication: workspace.left.application, rightApplication: workspace.right.application)
                        if let result = model.results[workspace.id], !result.succeeded || result.hasMatchedWindows {
                            Text(verbatim: result.message).font(.caption)
                                .foregroundStyle(result.succeeded ? Color.secondary : .orange)
                                .lineLimit(result.hasMatchedWindows ? 3 : 2).help(result.message)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: L10n.text("workspace.selectCombination"), workspace.name))
            .accessibilityValue(L10n.text(model.selectedIDs.contains(workspace.id) ? "workspace.selected" : "workspace.notSelected"))
            WorkspaceActionButtons(workspaceID: workspace.id, model: model)
        }
        .padding(12)
        .background(.primary.opacity(hovered ? 0.06 : 0.025), in: RoundedRectangle(cornerRadius: 10))
        .onHover { hovered = $0 }
        .disabled(model.isBusy)
        .accessibilityElement(children: .contain)
    }
}
