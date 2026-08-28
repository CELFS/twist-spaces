import SwiftUI

struct IconActionButton: View {
    let titleKey: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(AppButtonStyle(cornerRadius: 8))
        .help(L10n.text(titleKey))
        .accessibilityLabel(L10n.text(titleKey))
    }
}
