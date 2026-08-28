import SwiftUI

struct WorkspacePanelView: View {
    @ObservedObject var model: WorkspaceViewModel
    @ObservedObject var panelSettings: PanelSettings
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
                QuitApplicationButton(iconOnly: true)
                Button(action: close) { Image(systemName: "xmark") }.help(L10n.text("panel.close"))
                    .accessibilityLabel(L10n.text("panel.close"))
            }
            .buttonStyle(.plain)
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        QuickLaunchSection(model: model, settings: panelSettings, availableWidth: geometry.size.width) {
                            model.controlTab = .quickLaunch
                            settings()
                        }
                        Divider()
                        if model.library.workspaces.isEmpty {
                            Text(L10n.text("display.empty")).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                            Button(L10n.text("control.title"), action: settings).frame(maxWidth: .infinity)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(model.library.workspaces) { workspace in
                                    WorkspaceCardView(workspace: workspace, model: model)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
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
                Button(L10n.text("launch.batchActivate")) { Task { await model.openApplications(for: model.selectedIDs, action: .activate) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedIDs.isEmpty || model.isBusy)
                Button(L10n.text("launch.batchNew")) { Task { await model.openApplications(for: model.selectedIDs, action: .newWindows) } }
                    .buttonStyle(.bordered)
                    .disabled(model.selectedIDs.isEmpty || model.isBusy)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(language.selection)
    }
}
