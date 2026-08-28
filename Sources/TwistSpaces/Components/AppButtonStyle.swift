import SwiftUI

struct AppButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 6
    var idleOpacity: Double = 0
    var hoverOpacity: Double = 0.1
    var isSelected = false
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.primary.opacity(isSelected ? 0.18 : (isEnabled && hovered ? hoverOpacity : idleOpacity)),
                        in: RoundedRectangle(cornerRadius: cornerRadius))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.45)
            .contentShape(Rectangle())
            .appControlHover($hovered)
            .animation(.easeInOut(duration: 0.12), value: isEnabled && hovered)
    }
}
