import SwiftUI

struct WorkspaceControlView: View {
    @ObservedObject var model: WorkspaceViewModel
    @ObservedObject var settings: PanelSettings
    @ObservedObject private var language = LanguageSettings.shared
    @State private var showsDisplayResetConfirmation = false
    let showPanel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceControlSidebar(selection: $model.controlTab, showPanel: showPanel)
            Divider()
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.text(model.controlTab.titleKey)).font(.title2.bold())
                    Spacer()
                    if model.controlTab == .display {
                        Button {
                            showsDisplayResetConfirmation = true
                        } label: {
                            Label(L10n.text("panel.reset"), systemImage: "arrow.counterclockwise")
                        }
                        .appControlHover()
                    }
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
                    QuitApplicationButton(showsIcon: true)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .frame(minWidth: 620)
        }
        .frame(minHeight: 420)
        .buttonStyle(AppNativeButtonStyle())
        .id(language.selection)
        .sheet(item: $model.draft) { draft in
            WorkspaceEditorView(model: model, draft: draft)
        }
        .confirmationDialog(
            L10n.text("panel.resetTitle"),
            isPresented: $showsDisplayResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("panel.reset"), role: .destructive) {
                settings.resetDisplaySettings()
            }
            Button(L10n.text("workspace.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("panel.resetMessage"))
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
