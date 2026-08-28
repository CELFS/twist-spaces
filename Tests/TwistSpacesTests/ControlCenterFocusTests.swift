import AppKit
import Testing
@testable import TwistSpaces

@Test @MainActor func titlebarPanelButtonUsesAnIconAndDisablesNativeFocusRing() throws {
    let model = WorkspaceViewModel(catalog: { [] })
    var activationCount = 0
    let controller = WorkspaceControlController(model: model, settings: PanelSettings(), showPanel: { activationCount += 1 })
    let content = try #require(controller.window?.titlebarAccessoryViewControllers.first?.view)
    content.layoutSubtreeIfNeeded()

    func findButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == L10n.text("control.showPanel") {
            return button
        }
        return view.subviews.lazy.compactMap { findButton(in: $0) }.first
    }

    let button = try #require(findButton(in: content))
    #expect(button.focusRingType == .none)
    #expect(button.imagePosition == .imageOnly)
    #expect(button.image != nil)
    #expect(!button.isBordered)
    #expect(button.toolTip == L10n.text("control.showPanel"))
    #expect(button.isEnabled)
    button.performClick(nil)
    #expect(activationCount == 1)
}
