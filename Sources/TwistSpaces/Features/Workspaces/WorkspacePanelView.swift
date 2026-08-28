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
                AppLogoView(size: 20, monochrome: true)
                Text(L10n.text("workspace.title")).font(.headline)
                Spacer()
                GitHubLink()
                    .focusEffectDisabled()
                Button { panelSettings.isPinned.toggle() } label: {
                    Image(systemName: panelSettings.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(panelSettings.isPinned ? Color.accentColor : Color.primary)
                }
                .focusEffectDisabled()
                .help(L10n.text(panelSettings.isPinned ? "panel.unpin" : "panel.pin"))
                .accessibilityLabel(L10n.text(panelSettings.isPinned ? "panel.unpin" : "panel.pin"))
                .accessibilityAddTraits(panelSettings.isPinned ? .isSelected : [])
                Button(action: settings) { Image(systemName: "slider.horizontal.3") }.help(L10n.text("control.title"))
                    .accessibilityLabel(L10n.text("control.title"))
                Button(action: close) { Image(systemName: "xmark") }.help(L10n.text("panel.close"))
                    .accessibilityLabel(L10n.text("panel.close"))
            }
            .buttonStyle(AppButtonStyle())
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 16) {
                    QuickLaunchSection(model: model, settings: panelSettings, availableWidth: geometry.size.width) {
                        model.controlTab = .quickLaunch
                        settings()
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    // Quick Launch stays above the viewport; only combinations scroll.
                    ScrollView {
                        if model.library.workspaces.isEmpty {
                            VStack {
                                Text(L10n.text("display.empty")).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                                Button(L10n.text("control.title"), action: settings).frame(maxWidth: .infinity)
                            }
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
                }.buttonStyle(AppTextButtonStyle()).disabled(model.library.workspaces.isEmpty || model.isBusy)
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
                Button(L10n.text("launch.batchActivate")) { Task { await model.openApplications(for: model.selectedIDs, action: .activate) } }
                    .buttonStyle(AppNativeButtonStyle(prominent: true))
                    .disabled(model.selectedIDs.isEmpty || model.isBusy)
                Button(L10n.text("launch.batchNew")) { Task { await model.openApplications(for: model.selectedIDs, action: .newWindows) } }
                    .buttonStyle(AppNativeButtonStyle())
                    .disabled(model.selectedIDs.isEmpty || model.isBusy)
            }
            HStack {
                Spacer()
                QuitApplicationButton()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .buttonStyle(AppNativeButtonStyle())
        .id(language.selection)
    }
}
