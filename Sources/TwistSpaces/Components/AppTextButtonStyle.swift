import SwiftUI

struct AppTextButtonStyle: ButtonStyle {
    var idleColor: Color = .primary
    var hoverColor: Color = .accentColor
    var verticalPadding: CGFloat = 0
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled && hovered ? hoverColor : idleColor)
            .underline(isEnabled && hovered)
            .opacity(isEnabled ? (configuration.isPressed ? 0.55 : 1) : 0.45)
            .padding(.vertical, verticalPadding)
            .contentShape(Rectangle())
            .appControlHover($hovered)
            .animation(.easeInOut(duration: 0.12), value: isEnabled && hovered)
    }
}
