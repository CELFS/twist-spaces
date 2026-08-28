import SwiftUI

struct WorkspaceControlView: View {
    @ObservedObject var model: WorkspaceViewModel
    @ObservedObject var settings: PanelSettings
    @ObservedObject private var language = LanguageSettings.shared
    let showPanel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceControlSidebar(selection: $model.controlTab, showPanel: showPanel)
            Divider()
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.text(model.controlTab.titleKey)).font(.title2.bold())
                    Spacer()
                }
                .padding(.bottom, 8)
                selectedPage
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if let error = model.error {
                    Text(verbatim: error).foregroundStyle(.red).font(.callout).textSelection(.enabled)
                        .padding(.top, 16)
                }
                HStack {
                    Spacer()
                    RestartApplicationButton()
                        .padding(.trailing, 8)
                    QuitApplicationButton()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .frame(minWidth: 620)
        }
        .frame(minHeight: 420)
        .id(language.selection)
        .sheet(item: $model.draft) { draft in
            WorkspaceEditorView(model: model, draft: draft)
        }
    }

    @ViewBuilder private var selectedPage: some View {
        switch model.controlTab {
        case .combinations:
            CombinationsManagementView(model: model)
        case .quickLaunch:
            QuickLaunchManagementView(model: model, settings: settings)
        case .display:
            PanelSettingsView(settings: settings)
        case .language:
            SettingsPage {
                AppPicker(titleKey: "language.title", selection: $language.selection, width: .compact) {
                    Text(L10n.text("language.system")).tag(AppLanguage.system)
                    Text(L10n.text("language.english")).tag(AppLanguage.english)
                    Text(L10n.text("language.chinese")).tag(AppLanguage.simplifiedChinese)
                }
            }
        case .about:
            AboutView()
        }
    }
}
