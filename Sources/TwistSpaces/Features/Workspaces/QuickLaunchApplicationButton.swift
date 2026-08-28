import AppKit
import SwiftUI

struct QuickLaunchApplicationButton: View {
    let application: SavedApplication
    let showName: Bool
    let isOpening: Bool
    let result: WorkspaceLaunchResult?
    let open: () -> Void
    let hide: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 5) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: application.bundlePath))
                    .resizable().frame(width: 36, height: 36)
                    .overlay(alignment: .bottomTrailing) {
                        if isOpening {
                            ProgressView().controlSize(.mini)
                        } else if let result {
                            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(result.succeeded ? Color.accentColor : .orange)
                                .background(.background, in: Circle())
                        }
                    }
                if showName { Text(verbatim: application.name).font(.caption).lineLimit(1) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: showName ? 76 : 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(AppButtonStyle(cornerRadius: 8, idleOpacity: 0.025, hoverOpacity: 0.08))
        .help(String(format: L10n.text("quickLaunch.openApplication"), application.name))
        .accessibilityLabel(String(format: L10n.text("quickLaunch.openApplication"), application.name))
        .contextMenu { Button(L10n.text("quickLaunch.hide"), action: hide).buttonStyle(.automatic) }
    }
}
