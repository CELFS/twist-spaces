import AppKit

final class ProjectTagPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentView: NSView) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        self.contentView = contentView
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isMovable = false
        level = .statusBar
        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllApplications, .stationary, .ignoresCycle]
        animationBehavior = .none
        isReleasedWhenClosed = false
    }
}
