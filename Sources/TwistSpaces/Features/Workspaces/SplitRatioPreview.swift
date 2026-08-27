import SwiftUI

struct SplitRatioPreview: View {
    let leftPercentage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(format: L10n.text("workspace.ratioValue"), leftPercentage, 100 - leftPercentage))
                .font(.caption).foregroundStyle(.secondary)
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2).fill(.tint.opacity(0.65))
                        .frame(width: max(0, geometry.size.width - 2) * Double(leftPercentage) / 100)
                    RoundedRectangle(cornerRadius: 2).fill(.primary.opacity(0.2))
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
    }
}
