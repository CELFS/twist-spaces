import AppKit
import SwiftUI

struct QuitApplicationButton: View {
    var body: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Text(L10n.text("action.quit"))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(L10n.text("menu.quit"))
        .accessibilityLabel(L10n.text("menu.quit"))
    }
}
