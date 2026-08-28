import AppKit
import SwiftUI

struct ShowPanelButton: NSViewRepresentable {
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.showPanel))
        button.bezelStyle = .recessed
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: title)
        button.imagePosition = .imageOnly
        button.contentTintColor = .labelColor
        button.controlSize = .regular
        button.font = .systemFont(ofSize: NSFont.systemFontSize)
        // Keep native keyboard activation without drawing the automatic blue focus ring.
        button.focusRingType = .none
        button.isEnabled = isEnabled
        button.toolTip = title
        button.setAccessibilityLabel(title)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        button.title = title
        button.imagePosition = .imageOnly
        button.toolTip = title
        button.setAccessibilityLabel(title)
        button.isEnabled = isEnabled
        context.coordinator.action = action
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSButton, context: Context) -> CGSize? {
        CGSize(width: 40, height: 28)
    }

    @MainActor final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func showPanel() {
            action()
        }
    }
}
