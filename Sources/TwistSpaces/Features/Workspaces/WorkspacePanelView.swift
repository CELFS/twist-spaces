import SwiftUI

struct WorkspacePanelView: View {
    @ObservedObject var model: WorkspaceViewModel
    let close: () -> Void
    let settings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(L10n.text("app.name"), systemImage: "rectangle.split.2x1").font(.title2.bold())
                Spacer()
                Button(action: settings) { Image(systemName: "slider.horizontal.3") }.help(L10n.text("panel.settings"))
                Button(action: close) { Image(systemName: "xmark") }.help(L10n.text("panel.close"))
            }
            HStack {
                Text(L10n.text("workspace.title")).font(.headline)
                Spacer()
                Button(L10n.text("workspace.new")) { model.newWorkspace() }
                    .disabled(!model.canSave || model.isBusy)
            }
            if model.library.workspaces.isEmpty {
                ContentUnavailableView {
                    Label(L10n.text("workspace.emptyTitle"), systemImage: "rectangle.stack")
                } description: {
                    Text(L10n.text("workspace.emptyDescription"))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.library.workspaces) { workspace in
                            WorkspaceCardView(workspace: workspace, model: model)
                        }
                    }
                }
            }
            Divider()
            Text(L10n.text("workspace.openBoundary")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(String(format: L10n.text("workspace.selectedCount"), model.selectedIDs.count)).font(.caption)
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
                Button(L10n.text("workspace.showSelected")) { Task { await model.showWindows(for: model.selectedIDs) } }
                    .disabled(model.selectedIDs.isEmpty || model.isBusy)
            }
        }
        .padding(20)
        .frame(minWidth: 380, minHeight: 440)
        .sheet(item: $model.draft) { _ in
            if let draft = Binding($model.draft) { WorkspaceEditorView(model: model, draft: draft) }
        }
        .alert(L10n.text("workspace.errorTitle"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(L10n.text("workspace.ok")) { model.error = nil }
        } message: {
            Text(verbatim: model.error ?? "")
        }
    }
}
