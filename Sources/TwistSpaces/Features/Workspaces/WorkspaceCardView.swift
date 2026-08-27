import SwiftUI

struct WorkspaceCardView: View {
    let workspace: Workspace
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle(isOn: Binding(
                    get: { model.selectedIDs.contains(workspace.id) },
                    set: { if $0 { model.selectedIDs.insert(workspace.id) } else { model.selectedIDs.remove(workspace.id) } }
                )) { Text(verbatim: workspace.name).font(.headline) }
                    .toggleStyle(.checkbox)
                Spacer()
                Button(L10n.text("workspace.edit")) { model.edit(workspace) }
            }
            Text(verbatim: workspace.projectPath).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            WorkspaceWindowSummary(titleKey: "workspace.leftWindow", window: workspace.left)
            WorkspaceWindowSummary(titleKey: "workspace.rightWindow", window: workspace.right)
            HStack {
                Label(L10n.text("workspace.nativeLayout"), systemImage: "rectangle.split.2x1").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("workspace.showWindows")) { Task { await model.showWindows(for: [workspace.id]) } }
            }
            if let result = model.results[workspace.id] {
                Text(verbatim: result).font(.caption).textSelection(.enabled)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
        .disabled(model.isBusy)
    }
}

struct WorkspaceWindowSummary: View {
    let titleKey: String
    let window: SavedWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.text(titleKey)).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: window.applicationName).font(.subheadline.weight(.medium))
            Text(verbatim: window.title.isEmpty ? L10n.text("workspace.untitledWindow") : window.title)
                .font(.caption).lineLimit(2).help(window.title)
        }
    }
}
