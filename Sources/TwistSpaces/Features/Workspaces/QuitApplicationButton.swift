import AppKit
import SwiftUI

struct QuitApplicationButton: View {
    var iconOnly = false

    var body: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            if iconOnly {
                Image(systemName: "power")
            } else {
                Text(L10n.text("menu.quit"))
            }
        }
        .help(L10n.text("menu.quit"))
        .accessibilityLabel(L10n.text("menu.quit"))
    }
}
