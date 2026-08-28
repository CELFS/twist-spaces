import SwiftUI

struct QuickLaunchSection: View {
    @ObservedObject var model: WorkspaceViewModel
    @ObservedObject var settings: PanelSettings
    let availableWidth: Double
    let manage: () -> Void

    var body: some View {
        let applications = model.quickLaunchApplications
        let columns = QuickLaunchLayout.columnCount(width: availableWidth, showNames: settings.quickLaunchShowNames)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(L10n.text("quickLaunch.title")).font(.subheadline.weight(.semibold))
                Text(applications.count, format: .number).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                IconActionButton(titleKey: settings.quickLaunchShowNames ? "quickLaunch.hideNames" : "quickLaunch.showNames",
                                 symbol: "text.below.photo") { settings.quickLaunchShowNames.toggle() }
                    .foregroundStyle(settings.quickLaunchShowNames ? Color.accentColor : Color.secondary)
                IconActionButton(titleKey: "quickLaunch.manage", symbol: "slider.horizontal.3", action: manage)
                IconActionButton(titleKey: settings.quickLaunchExpanded ? "quickLaunch.collapse" : "quickLaunch.expand",
                                 symbol: settings.quickLaunchExpanded ? "chevron.up" : "chevron.down") {
                    settings.quickLaunchExpanded.toggle()
                }
            }
            if applications.isEmpty {
                Text(L10n.text("quickLaunch.empty")).font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: QuickLaunchLayout.spacing), count: columns),
                          spacing: QuickLaunchLayout.spacing) {
                    ForEach(QuickLaunchLayout.displayedApplications(applications, width: availableWidth,
                                                                  showNames: settings.quickLaunchShowNames,
                                                                  expanded: settings.quickLaunchExpanded)) { application in
                        QuickLaunchApplicationButton(application: application, showName: settings.quickLaunchShowNames,
                                                     isOpening: model.openingQuickLaunchID == application.id,
                                                     result: model.quickLaunchOutcome?.application.id == application.id ? model.quickLaunchOutcome?.result : nil,
                                                     open: { Task { await model.openQuickLaunchApplication(application) } },
                                                     hide: { model.updateQuickLaunch { $0.setVisible(false, id: application.id) } })
                            .disabled(model.isBusy)
                    }
                }
            }
            if let outcome = model.quickLaunchOutcome, !outcome.result.succeeded {
                Text(verbatim: "\(outcome.application.name): \(outcome.result.message)")
                    .font(.caption).foregroundStyle(.orange).textSelection(.enabled)
            }
            if let error = model.error {
                Text(verbatim: error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
        }
    }
}
