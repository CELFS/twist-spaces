import SwiftUI

struct WorkspaceControlNavigationButton: View {
    let titleKey: String
    let symbol: String
    let isSelected: Bool
    var showsArrow = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .frame(width: 16)
                    .foregroundStyle(.white)
                Text(L10n.text(titleKey))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                if showsArrow {
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .padding(.horizontal, 10)
            .background(Color.primary.opacity(isSelected ? 0.18 : (hovered ? 0.1 : 0)),
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .pointerStyle(.link)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
