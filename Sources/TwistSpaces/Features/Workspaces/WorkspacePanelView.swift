import SwiftUI

struct WorkspacePanelView: View {
    @ObservedObject var model: WorkspaceViewModel
    @ObservedObject private var language = LanguageSettings.shared
    let close: () -> Void
    let settings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.text("workspace.title")).font(.headline)
                Spacer()
                Button(action: settings) { Image(systemName: "slider.horizontal.3") }.help(L10n.text("control.title"))
                    .accessibilityLabel(L10n.text("control.title"))
                Button(action: close) { Image(systemName: "xmark") }.help(L10n.text("panel.close"))
                    .accessibilityLabel(L10n.text("panel.close"))
            }
            .buttonStyle(.plain)
            if model.library.workspaces.isEmpty {
                Spacer()
                Text(L10n.text("display.empty")).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Button(L10n.text("control.title"), action: settings).frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.library.workspaces) { workspace in
                            WorkspaceCardView(workspace: workspace, model: model)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button(L10n.text(model.selectedIDs.count == model.library.workspaces.count && !model.selectedIDs.isEmpty ? "display.deselectAll" : "display.selectAll")) {
                    if model.selectedIDs.count == model.library.workspaces.count { model.selectedIDs.removeAll() }
                    else { model.selectedIDs = Set(model.library.workspaces.map(\.id)) }
                }.buttonStyle(.plain).disabled(model.library.workspaces.isEmpty || model.isBusy)
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
                Button(L10n.text("launch.batch")) { Task { await model.openApplications(for: model.selectedIDs) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedIDs.isEmpty || model.isBusy)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(language.selection)
    }
}
