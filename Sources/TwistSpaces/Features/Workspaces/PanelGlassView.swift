import AppKit

final class PanelGlassView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        // Keep the native backdrop at full alpha: fading it exposes sharp, unblurred desktop content.
        alphaValue = 1
        let mask = NSImage(size: NSSize(width: 26, height: 26), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        mask.resizingMode = .stretch
        maskImage = mask
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
