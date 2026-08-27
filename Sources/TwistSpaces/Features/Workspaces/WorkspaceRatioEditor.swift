import SwiftUI

struct WorkspaceRatioEditor: View {
    @ObservedObject var draft: WorkspaceDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.text("workspace.ratio"))
                Spacer()
                Text(String(format: L10n.text("workspace.ratioValue"), Int(draft.leftPercentage), 100 - Int(draft.leftPercentage)))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $draft.leftPercentage, in: 10...90, step: 5)
                .accessibilityLabel(L10n.text("workspace.ratio"))
            Text(L10n.text("workspace.ratioNotApplied")).font(.caption).foregroundStyle(.secondary)
        }
    }
}
