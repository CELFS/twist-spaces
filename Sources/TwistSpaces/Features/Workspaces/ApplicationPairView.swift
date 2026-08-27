import AppKit
import SwiftUI

struct ApplicationPairView: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: workspace.left.bundlePath))
                .resizable().frame(width: 32, height: 32)
            Text(verbatim: workspace.left.applicationName).lineLimit(1)
            Image(systemName: "plus").font(.system(size: 9)).foregroundStyle(.tertiary)
            Image(nsImage: NSWorkspace.shared.icon(forFile: workspace.right.bundlePath))
                .resizable().frame(width: 32, height: 32)
            Text(verbatim: workspace.right.applicationName).lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
