import SwiftUI

struct SplitScreenPreview: View {
    let leftPercentage: Double
    let leftApplication: SavedApplication?
    let rightApplication: SavedApplication?
    var showsDividerHandle = false
    var dividerHovered = false
    var dividerDragging = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: SplitRatioInteraction.dividerWidth) {
                SplitScreenPane(application: leftApplication, percentage: Int(leftPercentage), tint: .accentColor)
                    .frame(width: SplitRatioInteraction.contentWidth(in: geometry.size.width) * leftPercentage / 100)
                SplitScreenPane(application: rightApplication, percentage: 100 - Int(leftPercentage), tint: .secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(SplitRatioInteraction.inset)
            if showsDividerHandle {
                Rectangle().fill(Color.accentColor.opacity(dividerHovered || dividerDragging ? 0.5 : 0))
                    .frame(width: SplitRatioInteraction.dividerWidth, height: max(0, geometry.size.height - SplitRatioInteraction.inset * 2))
                    .position(x: SplitRatioInteraction.dividerPosition(percentage: leftPercentage, width: geometry.size.width),
                              y: geometry.size.height / 2)
                Capsule().fill(dividerHovered || dividerDragging ? Color.accentColor : Color.primary.opacity(0.65))
                    .frame(width: 4, height: 28)
                    .padding(4)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(dividerHovered || dividerDragging ? Color.accentColor : Color.primary.opacity(0.12)))
                    .scaleEffect(dividerDragging ? 1.2 : dividerHovered ? 1.1 : 1)
                    .shadow(color: Color.accentColor.opacity(dividerHovered || dividerDragging ? 0.3 : 0), radius: 4)
                    .animation(.easeOut(duration: 0.12), value: dividerHovered)
                    .animation(.easeOut(duration: 0.12), value: dividerDragging)
                    .position(x: SplitRatioInteraction.dividerPosition(percentage: leftPercentage, width: geometry.size.width),
                              y: geometry.size.height / 2)
            }
        }
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.18)))
    }
}
