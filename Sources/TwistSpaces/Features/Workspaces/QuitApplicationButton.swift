import AppKit
import SwiftUI

struct QuitApplicationButton: View {
    @State private var hovered = false

    var body: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Text(L10n.text("action.quit"))
        }
        .buttonStyle(QuitButtonStyle(hovered: hovered))
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
        .help(L10n.text("menu.quit"))
        .accessibilityLabel(L10n.text("menu.quit"))
    }
}
