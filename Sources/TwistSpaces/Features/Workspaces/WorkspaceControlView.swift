import SwiftUI

struct WorkspaceControlView: View {
    @ObservedObject var model: WorkspaceViewModel
    @ObservedObject var settings: PanelSettings
    @ObservedObject private var language = LanguageSettings.shared
    @State private var tab = 0
    let showPanel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.text("control.title")).font(.title2.bold())
                Spacer()
                Button(L10n.text("control.showPanel"), action: showPanel)
            }
            TabView(selection: $tab) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L10n.text("control.combinations")).font(.headline)
                        Spacer()
                        Button(L10n.text("workspace.new")) { model.newWorkspace() }
                            .disabled(!model.canSave || model.isBusy)
                    }
                    if model.library.workspaces.isEmpty {
                        ContentUnavailableView(L10n.text("control.empty"), systemImage: "rectangle.stack")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(model.library.workspaces) { workspace in
                                    WorkspaceManagementRow(workspace: workspace, model: model)
                                    Divider()
                                }
                            }
                        }
                    }
                    Text(L10n.text("control.layoutStatus")).font(.caption).foregroundStyle(.secondary)
                }
                .padding(16)
                .tabItem { Text(L10n.text("control.combinations")) }.tag(0)

                PanelSettingsView(settings: settings)
                    .tabItem { Text(L10n.text("control.display")) }.tag(1)

                VStack(alignment: .leading, spacing: 16) {
                    Picker(L10n.text("language.title"), selection: $language.selection) {
                        Text(L10n.text("language.system")).tag(AppLanguage.system)
                        Text(L10n.text("language.english")).tag(AppLanguage.english)
                        Text(L10n.text("language.chinese")).tag(AppLanguage.simplifiedChinese)
                    }
                    Spacer()
                }
                .padding(24)
                .tabItem { Text(L10n.text("language.title")) }.tag(2)
            }
            if let error = model.error {
                Text(verbatim: error).foregroundStyle(.red).font(.callout).textSelection(.enabled)
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 420)
        .id(language.selection)
        .sheet(item: $model.draft) { draft in
            WorkspaceEditorView(model: model, draft: draft)
        }
    }
}
