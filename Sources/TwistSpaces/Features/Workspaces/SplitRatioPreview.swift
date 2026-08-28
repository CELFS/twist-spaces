import SwiftUI

struct SplitRatioPreview: View {
    let leftPercentage: Int
    let leftApplication: SavedApplication
    let rightApplication: SavedApplication

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(format: L10n.text("workspace.ratioValue"), leftPercentage, 100 - leftPercentage))
                .font(.caption).foregroundStyle(.secondary)
            SplitScreenPreview(leftPercentage: Double(leftPercentage), leftApplication: leftApplication, rightApplication: rightApplication)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: 240)
                .accessibilityHidden(true)
        }
    }
}
