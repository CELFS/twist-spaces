import AppKit
import SwiftUI

@MainActor
final class AppControlCursor {
    private static weak var owner: AppControlCursor?

    @discardableResult
    func update(isInside: Bool, isEnabled: Bool) -> Bool {
        let active = isInside && isEnabled
        if active {
            Self.owner = self
            NSCursor.pointingHand.set()
        } else {
            deactivate()
        }
        return active
    }

    func deactivate() {
        // An old control's exit/disappearance must not reset a newer control's cursor.
        guard Self.owner === self else { return }
        Self.owner = nil
        if NSCursor.current == .pointingHand { NSCursor.arrow.set() }
    }
}

private struct AppControlHover: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var hovered: Bool
    @State private var isInside = false
    @State private var cursor = AppControlCursor()

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active: isInside = true
                case .ended: isInside = false
                }
                updateHover()
            }
            .onChange(of: isEnabled) { _, _ in updateHover() }
            .onDisappear {
                isInside = false
                hovered = false
                cursor.deactivate()
            }
    }

    private func updateHover() {
        hovered = cursor.update(isInside: isInside, isEnabled: isEnabled)
    }
}

extension View {
    func appControlHover(_ hovered: Binding<Bool> = .constant(false)) -> some View {
        modifier(AppControlHover(hovered: hovered))
    }
}
