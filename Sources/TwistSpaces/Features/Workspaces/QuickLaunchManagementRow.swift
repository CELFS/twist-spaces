import AppKit
import SwiftUI

struct QuickLaunchManagementRow: View {
    let application: SavedApplication
    let sourceKey: String
    let isVisible: Bool
    let isManual: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let toggleVisibility: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.bundlePath))
                .resizable().frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: application.name).lineLimit(1)
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary)
                Text(L10n.text(sourceKey)).font(.caption).foregroundStyle(.secondary)
            }
            .help(application.bundlePath)
            Spacer(minLength: 0)
            IconActionButton(titleKey: "quickLaunch.moveUp", symbol: "arrow.up", action: moveUp).disabled(!canMoveUp)
            IconActionButton(titleKey: "quickLaunch.moveDown", symbol: "arrow.down", action: moveDown).disabled(!canMoveDown)
            IconActionButton(titleKey: isVisible ? "quickLaunch.hide" : "quickLaunch.show",
                             symbol: isVisible ? "eye" : "eye.slash", action: toggleVisibility)
            if isManual {
                IconActionButton(titleKey: "quickLaunch.removeManual", symbol: "minus.circle", action: remove)
            } else {
                Color.clear.frame(width: 36, height: 36).accessibilityHidden(true)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(application.name)
    }
}
