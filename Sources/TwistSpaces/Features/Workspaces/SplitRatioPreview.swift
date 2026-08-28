import SwiftUI

struct SplitRatioPreview: View {
    let leftPercentage: Int
    let leftApplication: SavedApplication
    let rightApplication: SavedApplication

    var body: some View {
        SplitScreenPreview(leftPercentage: Double(leftPercentage), leftApplication: leftApplication, rightApplication: rightApplication)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: 144)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: L10n.text("workspace.ratioValue"), leftPercentage, 100 - leftPercentage))
    }
}
