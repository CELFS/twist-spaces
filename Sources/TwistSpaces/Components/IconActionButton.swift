import SwiftUI

struct IconActionButton: View {
    let titleKey: String
    let symbol: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .background(.primary.opacity(hovered ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(L10n.text(titleKey))
        .accessibilityLabel(L10n.text(titleKey))
    }
}
