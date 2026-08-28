import AppKit
import SwiftUI

struct RestartApplicationButton: View {
    @ObservedObject private var restarter = ApplicationRestarter.shared

    var body: some View {
        Button {
            restarter.restart(nil)
        } label: {
            Label(L10n.text("action.restart"), systemImage: "arrow.clockwise")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(QuitButtonStyle())
        .disabled(restarter.isRestarting)
        .help(L10n.text("menu.restart"))
        .accessibilityLabel(L10n.text("menu.restart"))
    }
}
