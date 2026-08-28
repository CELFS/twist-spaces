import SwiftUI

struct QuitButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Keep the lightweight appearance while making hover and mouse-down visible.
        Button(configuration)
            .buttonStyle(AppTextButtonStyle(idleColor: .secondary, hoverColor: .primary, verticalPadding: 3))
    }
}
