import Combine
import Foundation
import SwiftUI

@MainActor
final class PanelSettings: ObservableObject {
    @Published var leftSide: Bool { didSet { defaults.set(leftSide, forKey: "panel.leftSide") } }
    @Published var width: Double { didSet { defaults.set(width, forKey: "panel.width") } }
    @Published var edgeEnabled: Bool { didSet { defaults.set(edgeEnabled, forKey: "panel.edgeEnabled") } }
    @Published var edgeDelay: Double { didSet { defaults.set(edgeDelay, forKey: "panel.edgeDelay") } }
    @Published var shortcutEnabled: Bool { didSet { defaults.set(shortcutEnabled, forKey: "panel.shortcutEnabled") } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        leftSide = defaults.bool(forKey: "panel.leftSide")
        let storedWidth = defaults.double(forKey: "panel.width")
        width = storedWidth == 0 ? 460 : min(max(storedWidth, 380), 700)
        edgeEnabled = defaults.bool(forKey: "panel.edgeEnabled")
        let storedDelay = defaults.double(forKey: "panel.edgeDelay")
        edgeDelay = storedDelay == 0 ? 0.6 : min(max(storedDelay, 0.2), 2)
        shortcutEnabled = defaults.bool(forKey: "panel.shortcutEnabled")
    }
}

struct PanelSettingsView: View {
    @ObservedObject var settings: PanelSettings
    let done: () -> Void

    var body: some View {
        Form {
            Picker(L10n.text("panel.side"), selection: $settings.leftSide) {
                Text(L10n.text("panel.left")).tag(true)
                Text(L10n.text("panel.right")).tag(false)
            }
            Slider(value: $settings.width, in: 380...700, step: 20) {
                Text(String(format: L10n.text("panel.width"), Int(settings.width)))
            }
            Toggle(L10n.text("panel.edgeEnabled"), isOn: $settings.edgeEnabled)
            Slider(value: $settings.edgeDelay, in: 0.2...2, step: 0.1) {
                Text(String(format: L10n.text("panel.edgeDelay"), settings.edgeDelay))
            }.disabled(!settings.edgeEnabled)
            Toggle(L10n.text("panel.shortcutEnabled"), isOn: $settings.shortcutEnabled)
            Text(L10n.text("panel.behaviorHelp")).font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button(L10n.text("panel.done"), action: done).keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 460)
    }
}
