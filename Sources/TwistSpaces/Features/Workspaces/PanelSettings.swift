import Combine
import Foundation
import SwiftUI

@MainActor
final class PanelSettings: ObservableObject {
    @Published var leftSide: Bool { didSet { defaults.set(leftSide, forKey: "panel.leftSide") } }
    @Published var width: Double { didSet { defaults.set(width, forKey: "panel.displayWidth") } }
    @Published var edgeEnabled: Bool { didSet { defaults.set(edgeEnabled, forKey: "panel.edgeEnabled") } }
    @Published var edgeDelay: Double { didSet { defaults.set(edgeDelay, forKey: "panel.edgeDelay") } }
    @Published var shortcutEnabled: Bool { didSet { defaults.set(shortcutEnabled, forKey: "panel.shortcutEnabled") } }
    @Published var quickLaunchExpanded: Bool { didSet { defaults.set(quickLaunchExpanded, forKey: "panel.quickLaunchExpanded") } }
    @Published var quickLaunchShowNames: Bool { didSet { defaults.set(quickLaunchShowNames, forKey: "panel.quickLaunchShowNames") } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        leftSide = defaults.bool(forKey: "panel.leftSide")
        // Migrate the previous default once; later explicit width choices survive relaunch.
        var storedWidth: Double
        if defaults.object(forKey: "panel.displayWidth") != nil {
            storedWidth = defaults.double(forKey: "panel.displayWidth")
        } else {
            let previous = defaults.double(forKey: "panel.width")
            storedWidth = previous == 0 || previous == 460 ? PanelAppearance.defaultWidth : previous
        }
        if defaults.integer(forKey: "panel.widthRevision") < 2 && storedWidth == 340 {
            storedWidth = PanelAppearance.defaultWidth
        }
        width = storedWidth.isFinite ? min(max(storedWidth, PanelAppearance.widthRange.lowerBound), PanelAppearance.widthRange.upperBound) : PanelAppearance.defaultWidth
        edgeEnabled = defaults.bool(forKey: "panel.edgeEnabled")
        let storedDelay = defaults.double(forKey: "panel.edgeDelay")
        edgeDelay = storedDelay == 0 ? 0.6 : min(max(storedDelay, 0.2), 2)
        shortcutEnabled = defaults.bool(forKey: "panel.shortcutEnabled")
        quickLaunchExpanded = defaults.bool(forKey: "panel.quickLaunchExpanded")
        quickLaunchShowNames = defaults.bool(forKey: "panel.quickLaunchShowNames")
        defaults.set(width, forKey: "panel.displayWidth")
        defaults.set(2, forKey: "panel.widthRevision")
    }
}

struct PanelSettingsView: View {
    @ObservedObject var settings: PanelSettings

    var body: some View {
        SettingsPage {
            AppPicker(titleKey: "panel.side", selection: $settings.leftSide, width: .compact) {
                Text(L10n.text("panel.left")).tag(true)
                Text(L10n.text("panel.right")).tag(false)
            }
            HStack(spacing: AppFormLayout.spacing) {
                Text(String(format: L10n.text("panel.width"), Int(settings.width)))
                    .frame(width: AppFormLayout.labelWidth, alignment: .trailing)
                Slider(value: $settings.width, in: PanelAppearance.widthRange, step: 20)
                    .accessibilityLabel(String(format: L10n.text("panel.width"), Int(settings.width)))
                    .frame(maxWidth: .infinity)
            }
            Toggle(L10n.text("panel.edgeEnabled"), isOn: $settings.edgeEnabled)
                .padding(.leading, AppFormLayout.contentInset)
            HStack(spacing: AppFormLayout.spacing) {
                Text(String(format: L10n.text("panel.edgeDelay"), settings.edgeDelay))
                    .frame(width: AppFormLayout.labelWidth, alignment: .trailing)
                Slider(value: $settings.edgeDelay, in: 0.2...2, step: 0.1)
                    .accessibilityLabel(String(format: L10n.text("panel.edgeDelay"), settings.edgeDelay))
                    .frame(maxWidth: .infinity)
            }.disabled(!settings.edgeEnabled)
            Toggle(L10n.text("panel.shortcutEnabled"), isOn: $settings.shortcutEnabled)
                .padding(.leading, AppFormLayout.contentInset)
            Text(L10n.text("panel.behaviorHelp")).font(.caption).foregroundStyle(.secondary)
                .padding(.leading, AppFormLayout.contentInset)
        }
    }
}
