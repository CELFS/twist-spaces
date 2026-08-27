import Foundation

enum PanelAppearance {
    static let defaultWidth = 460.0
    static let widthRange = 300.0...700.0
    static let screenInset = 12.0

    static func frame(in visibleFrame: CGRect, width: Double, leftSide: Bool) -> CGRect {
        let inset = min(screenInset, max(0, min(visibleFrame.width, visibleFrame.height) / 2))
        let available = visibleFrame.insetBy(dx: inset, dy: inset)
        let panelWidth = min(max(0, width), available.width)
        return CGRect(x: leftSide ? available.minX : available.maxX - panelWidth,
                      y: available.minY, width: panelWidth, height: available.height)
    }
}
