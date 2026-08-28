import SwiftUI

struct QuitButtonStyle: ButtonStyle {
    let hovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        // Keep the text-only appearance while making hover and mouse-down visible.
        configuration.label
            .foregroundStyle(hovered ? Color.primary : Color.secondary)
            .underline(hovered)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
    }
}
