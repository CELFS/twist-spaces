import Combine
import Foundation
import SwiftUI

@MainActor
final class PanelSettings: ObservableObject {
    static let defaultLeftSide = false
    static let defaultEdgeEnabled = false
    static let defaultEdgeDelay = 0.6
    static let defaultShortcutEnabled = false
    static let defaultProjectTagsEnabled = true

    // Pinning survives manual collapse, but is not persisted between app launches.
    @Published var isPinned = false
    @Published var leftSide: Bool { didSet { defaults.set(leftSide, forKey: "panel.leftSide") } }
    @Published var width: Double { didSet { defaults.set(width, forKey: "panel.displayWidth") } }
    @Published var edgeEnabled: Bool { didSet { defaults.set(edgeEnabled, forKey: "panel.edgeEnabled") } }
    @Published var edgeDelay: Double { didSet { defaults.set(edgeDelay, forKey: "panel.edgeDelay") } }
    @Published var windowStabilityDelay: Double { didSet { defaults.set(windowStabilityDelay, forKey: "window.minimumStabilityDelay") } }
    @Published var shortcutEnabled: Bool { didSet { defaults.set(shortcutEnabled, forKey: "panel.shortcutEnabled") } }
    @Published var quickLaunchExpanded: Bool { didSet { defaults.set(quickLaunchExpanded, forKey: "panel.quickLaunchExpanded") } }
    @Published var quickLaunchShowNames: Bool { didSet { defaults.set(quickLaunchShowNames, forKey: "panel.quickLaunchShowNames") } }
    @Published var projectTagsEnabled: Bool { didSet { defaults.set(projectTagsEnabled, forKey: "projectTags.enabled") } }
    @Published private(set) var hiddenProjectTagNames: [String] {
        didSet { defaults.set(hiddenProjectTagNames, forKey: "projectTags.hiddenNames") }
    }
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
        edgeDelay = storedDelay == 0 ? Self.defaultEdgeDelay : min(max(storedDelay, 0.2), 2)
        let storedWindowDelay = defaults.object(forKey: "window.minimumStabilityDelay") == nil
            ? WindowStabilityPolicy.defaultMinimumAge
            : defaults.double(forKey: "window.minimumStabilityDelay")
        windowStabilityDelay = WindowStabilityPolicy.clampedMinimumAge(storedWindowDelay)
        shortcutEnabled = defaults.bool(forKey: "panel.shortcutEnabled")
        quickLaunchExpanded = defaults.bool(forKey: "panel.quickLaunchExpanded")
        quickLaunchShowNames = defaults.bool(forKey: "panel.quickLaunchShowNames")
        projectTagsEnabled = defaults.object(forKey: "projectTags.enabled") == nil
            ? Self.defaultProjectTagsEnabled
            : defaults.bool(forKey: "projectTags.enabled")
        hiddenProjectTagNames = (defaults.stringArray(forKey: "projectTags.hiddenNames") ?? []).reduce(into: []) { names, raw in
            let name = Self.normalizedProjectTagName(raw)
            if !name.isEmpty, !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }
        defaults.set(width, forKey: "panel.displayWidth")
        defaults.set(windowStabilityDelay, forKey: "window.minimumStabilityDelay")
        defaults.set(projectTagsEnabled, forKey: "projectTags.enabled")
        defaults.set(hiddenProjectTagNames, forKey: "projectTags.hiddenNames")
        defaults.set(2, forKey: "panel.widthRevision")
    }

    static func normalizedProjectTagName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func addHiddenProjectTagName(_ raw: String) {
        let name = Self.normalizedProjectTagName(raw)
        guard !name.isEmpty,
              !hiddenProjectTagNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        hiddenProjectTagNames.append(name)
    }

    func removeHiddenProjectTagName(_ name: String) {
        hiddenProjectTagNames.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    func hidesProjectTag(named name: String) -> Bool {
        hiddenProjectTagNames.contains { $0.caseInsensitiveCompare(Self.normalizedProjectTagName(name)) == .orderedSame }
    }

    func resetDisplaySettings() {
        leftSide = Self.defaultLeftSide
        width = PanelAppearance.defaultWidth
        edgeEnabled = Self.defaultEdgeEnabled
        edgeDelay = Self.defaultEdgeDelay
        windowStabilityDelay = WindowStabilityPolicy.defaultMinimumAge
        shortcutEnabled = Self.defaultShortcutEnabled
    }
}

struct PanelSettingsView: View {
    @ObservedObject var settings: PanelSettings
    private let sliderRowMaxWidth: CGFloat = 520

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
            .frame(maxWidth: sliderRowMaxWidth)
            Toggle(L10n.text("panel.edgeEnabled"), isOn: $settings.edgeEnabled)
                .appControlHover()
                .padding(.leading, AppFormLayout.contentInset)
            HStack(spacing: AppFormLayout.spacing) {
                Text(String(format: L10n.text("panel.edgeDelay"), settings.edgeDelay))
                    .frame(width: AppFormLayout.labelWidth, alignment: .trailing)
                Slider(value: $settings.edgeDelay, in: 0.2...2, step: 0.1)
                    .accessibilityLabel(String(format: L10n.text("panel.edgeDelay"), settings.edgeDelay))
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: sliderRowMaxWidth)
            .disabled(!settings.edgeEnabled)
            HStack(spacing: AppFormLayout.spacing) {
                Text(String(format: L10n.text("panel.windowStabilityDelay"), settings.windowStabilityDelay))
                    .frame(width: AppFormLayout.labelWidth, alignment: .trailing)
                Slider(value: $settings.windowStabilityDelay, in: WindowStabilityPolicy.minimumAgeRange,
                       step: WindowStabilityPolicy.minimumAgeStep)
                    .accessibilityLabel(String(format: L10n.text("panel.windowStabilityDelay"), settings.windowStabilityDelay))
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: sliderRowMaxWidth)
            Text(L10n.text("panel.windowStabilityHelp")).font(.caption).foregroundStyle(.secondary)
                .padding(.leading, AppFormLayout.contentInset)
            Toggle(L10n.text("panel.shortcutEnabled"), isOn: $settings.shortcutEnabled)
                .appControlHover()
                .padding(.leading, AppFormLayout.contentInset)
            Text(L10n.text("panel.behaviorHelp")).font(.caption).foregroundStyle(.secondary)
                .padding(.leading, AppFormLayout.contentInset)
            ProjectTagSettingsView(settings: settings)
        }
    }
}
