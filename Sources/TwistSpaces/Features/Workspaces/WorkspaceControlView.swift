import SwiftUI

enum WorkspaceControlTab: Hashable { case combinations, quickLaunch, display, language, about }

struct WorkspaceControlView: View {
    @ObservedObject var model: WorkspaceViewModel
    @ObservedObject var settings: PanelSettings
    @ObservedObject private var language = LanguageSettings.shared
    let showPanel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.text("control.title")).font(.title2.bold())
                Spacer()
                Button(L10n.text("control.showPanel"), action: showPanel)
            }
            TabView(selection: $model.controlTab) {
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
                .padding(.vertical, 16)
                .tabItem { Text(L10n.text("control.combinations")) }.tag(WorkspaceControlTab.combinations)

                QuickLaunchManagementView(model: model, settings: settings)
                    .tabItem { Text(L10n.text("quickLaunch.title")) }.tag(WorkspaceControlTab.quickLaunch)

                PanelSettingsView(settings: settings)
                    .tabItem { Text(L10n.text("control.display")) }.tag(WorkspaceControlTab.display)

                SettingsPage {
                    AppPicker(titleKey: "language.title", selection: $language.selection, width: .compact) {
                        Text(L10n.text("language.system")).tag(AppLanguage.system)
                        Text(L10n.text("language.english")).tag(AppLanguage.english)
                        Text(L10n.text("language.chinese")).tag(AppLanguage.simplifiedChinese)
                    }
                }
                .tabItem { Text(L10n.text("language.title")) }.tag(WorkspaceControlTab.language)

                AboutView()
                    .tabItem { Text(L10n.text("about.title")) }.tag(WorkspaceControlTab.about)
            }
            if let error = model.error {
                Text(verbatim: error).foregroundStyle(.red).font(.callout).textSelection(.enabled)
            }
            HStack {
                Spacer()
                QuitApplicationButton()
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
