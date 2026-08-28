import AppKit
import SwiftUI

struct ApplicationPairView: View {
    let workspace: Workspace
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: workspace.left.bundlePath))
                .resizable().frame(width: compact ? 16 : 32, height: compact ? 16 : 32)
            Text(verbatim: workspace.left.applicationName).lineLimit(1).help(workspace.left.applicationName)
            Image(systemName: "plus").font(.system(size: 9)).foregroundStyle(.tertiary)
            Image(nsImage: NSWorkspace.shared.icon(forFile: workspace.right.bundlePath))
                .resizable().frame(width: compact ? 16 : 32, height: compact ? 16 : 32)
            Text(verbatim: workspace.right.applicationName).lineLimit(1).help(workspace.right.applicationName)
        }
        .font(compact ? .caption2 : .caption)
        .foregroundStyle(.secondary)
    }
}
