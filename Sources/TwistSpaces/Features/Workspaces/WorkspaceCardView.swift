import SwiftUI

struct WorkspaceCardView: View {
    let workspace: Workspace
    @ObservedObject var model: WorkspaceViewModel
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                    get: { model.selectedIDs.contains(workspace.id) },
                    set: { if $0 { model.selectedIDs.insert(workspace.id) } else { model.selectedIDs.remove(workspace.id) } }
            )) { Text(verbatim: workspace.name) }
                .toggleStyle(.checkbox).labelsHidden()
                .accessibilityLabel(workspace.name)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: workspace.name).font(.headline).lineLimit(1)
                ApplicationPairView(workspace: workspace)
            }
            Spacer(minLength: 0)
            if let result = model.results[workspace.id] {
                Image(systemName: result.succeeded ? "checkmark" : "exclamationmark.circle")
                    .foregroundStyle(result.succeeded ? Color.secondary : .orange)
                    .help(result.message)
                    .accessibilityLabel(result.message)
            }
            Button { Task { await model.openApplications(for: [workspace.id]) } } label: {
                Image(systemName: "arrow.up.forward")
            }
            .buttonStyle(.plain).help(L10n.text("launch.open"))
            .accessibilityLabel(L10n.text("launch.open"))
        }
        .padding(12)
        .background(.primary.opacity(hovered ? 0.06 : 0.025), in: RoundedRectangle(cornerRadius: 10))
        .onHover { hovered = $0 }
        .disabled(model.isBusy)
    }
}
