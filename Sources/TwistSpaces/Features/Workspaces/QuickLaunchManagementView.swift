import SwiftUI

struct QuickLaunchManagementView: View {
    @ObservedObject var model: WorkspaceViewModel
    @ObservedObject var settings: PanelSettings
    @State private var selection: SavedApplication?

    var body: some View {
        let configuration = model.library.quickLaunch
        let applications = configuration.applications(in: model.library.workspaces)
        let groupedIDs = Set(model.library.workspaces.flatMap(\.applications).map(\.id))
        let manualIDs = Set(configuration.addedApplications.map(\.id))
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("quickLaunch.managementHelp")).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Toggle(L10n.text("quickLaunch.showNames"), isOn: $settings.quickLaunchShowNames)
                Toggle(L10n.text("quickLaunch.expand"), isOn: $settings.quickLaunchExpanded)
            }
            HStack {
                ApplicationPickerView(titleKey: "quickLaunch.application", applications: model.applications,
                                      selection: $selection, browse: model.browseQuickLaunchApplications)
                Button(L10n.text("quickLaunch.add")) {
                    guard let selection else { return }
                    model.updateQuickLaunch { $0.add(selection) }
                    self.selection = nil
                }.disabled(selection == nil)
                IconActionButton(titleKey: "applications.refresh", symbol: "arrow.clockwise", action: model.refreshApplications)
            }
            .disabled(!model.canSave || model.isBusy)
            if applications.isEmpty {
                ContentUnavailableView(L10n.text("quickLaunch.emptyTitle"), systemImage: "app.dashed")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(applications.enumerated()), id: \.element.id) { index, application in
                            QuickLaunchManagementRow(
                                application: application,
                                sourceKey: groupedIDs.contains(application.id)
                                    ? (manualIDs.contains(application.id) ? "quickLaunch.sourceBoth" : "quickLaunch.sourceGroup")
                                    : "quickLaunch.sourceManual",
                                isVisible: !configuration.hiddenApplicationIDs.contains(application.id),
                                isManual: manualIDs.contains(application.id),
                                canMoveUp: index > 0, canMoveDown: index < applications.count - 1,
                                toggleVisibility: {
                                    model.updateQuickLaunch { $0.setVisible($0.hiddenApplicationIDs.contains(application.id), id: application.id) }
                                },
                                moveUp: { model.updateQuickLaunch { $0.move(application.id, by: -1, in: model.library.workspaces) } },
                                moveDown: { model.updateQuickLaunch { $0.move(application.id, by: 1, in: model.library.workspaces) } },
                                remove: { model.updateQuickLaunch { $0.removeManualApplication(application.id) } }
                            )
                            Divider()
                        }
                    }
                }
                .disabled(!model.canSave || model.isBusy)
            }
        }
        .padding(16)
        .onAppear { model.refreshApplications() }
    }
}
