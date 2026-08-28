import SwiftUI

struct WorkspaceControlNavigationButton: View {
    let titleKey: String
    let symbol: String
    let isSelected: Bool
    var showsArrow = false
    let action: () -> Void

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
            .contentShape(Rectangle())
        }
        .buttonStyle(AppButtonStyle(isSelected: isSelected))
        .focusEffectDisabled()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
