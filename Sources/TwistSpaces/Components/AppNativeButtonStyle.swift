import SwiftUI

struct AppNativeButtonStyle: PrimitiveButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        nativeButton(configuration)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(isEnabled && hovered ? 0.08 : 0))
                    .allowsHitTesting(false)
            }
            .appControlHover($hovered)
            .animation(.easeInOut(duration: 0.12), value: isEnabled && hovered)
    }

    @ViewBuilder private func nativeButton(_ configuration: Configuration) -> some View {
        // Keep native press tracking, keyboard shortcuts, focus, and disabled rendering.
        if prominent {
            Button(configuration).buttonStyle(.borderedProminent)
        } else {
            Button(configuration).buttonStyle(.automatic)
        }
    }
}
