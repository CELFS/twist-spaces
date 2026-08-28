import AppKit
import SwiftUI

struct QuitApplicationButton: View {
    var showsIcon = false

    var body: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            if showsIcon {
                Label(L10n.text("action.quit"), systemImage: "power")
                    .labelStyle(.titleAndIcon)
            } else {
                Text(L10n.text("action.quit"))
            }
        }
        .buttonStyle(QuitButtonStyle())
        .help(L10n.text("menu.quit"))
        .accessibilityLabel(L10n.text("menu.quit"))
    }
}
