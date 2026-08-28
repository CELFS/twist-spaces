import AppKit
import SwiftUI

struct RestartApplicationButton: View {
    @ObservedObject private var restarter = ApplicationRestarter.shared
    @State private var hovered = false

    var body: some View {
        Button {
            restarter.restart(nil)
        } label: {
            Text(L10n.text("action.restart"))
        }
        .buttonStyle(QuitButtonStyle(hovered: hovered))
        .disabled(restarter.isRestarting)
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hovered = true
                NSCursor.pointingHand.set()
            case .ended:
                hovered = false
                NSCursor.arrow.set()
            }
        }
        .onDisappear {
            if hovered { NSCursor.arrow.set() }
        }
        .help(L10n.text("menu.restart"))
        .accessibilityLabel(L10n.text("menu.restart"))
    }
}
