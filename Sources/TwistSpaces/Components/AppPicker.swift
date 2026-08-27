import SwiftUI

enum AppFormLayout {
    static let labelWidth: CGFloat = 120
    static let spacing: CGFloat = 12
    static let contentInset = labelWidth + spacing
}

enum AppPickerWidth: CGFloat {
    case compact = 140
    case regular = 240
    case wide = 360
}

struct AppPicker<Selection: Hashable, Options: View>: View {
    let titleKey: String
    @Binding var selection: Selection
    var width: AppPickerWidth = .regular
    @ViewBuilder let options: () -> Options

    var body: some View {
        HStack(spacing: AppFormLayout.spacing) {
            Text(L10n.text(titleKey))
                .frame(width: AppFormLayout.labelWidth, alignment: .trailing)
            Picker(L10n.text(titleKey), selection: $selection, content: options)
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.regular)
                .frame(width: width.rawValue)
                .accessibilityLabel(L10n.text(titleKey))
        }
    }
}
