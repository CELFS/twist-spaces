import Foundation

enum NativeSplitError: String, LocalizedError {
    case windowMissing, ambiguousWindow, focusFailed, alreadyFullscreen, menuUnavailable
    case selectionUnavailable, pairUnconfirmed, ratioUnavailable, cancelled
    var errorDescription: String? { L10n.text("split.error.\(rawValue)") }
}

struct NativeWindowToken: Hashable, Sendable { let value: Int }

struct NativeSplitRatioError: LocalizedError {
    let requested: Int
    let actual: Int
    var errorDescription: String? { String(format: L10n.text("split.ratioLimited"), actual, 100 - actual, requested, 100 - requested) }
}

enum NativeSplitMenu {
    static func isTileMenu(_ title: String) -> Bool {
        ["Full Screen Tile", "Full Screen", "全屏幕拼贴", "全螢幕並排", "全屏幕"].contains(title)
    }
    static func isLeftCommand(_ title: String, ancestors: [String]) -> Bool {
        if ["Tile Window to Left of Screen", "将窗口平铺到屏幕左侧", "將視窗並排到螢幕左側"].contains(title) { return true }
        return ancestors.contains(where: isTileMenu)
            && ["Left of Screen", "屏幕左侧", "螢幕左側"].contains(title)
    }
}

enum NativeSplitGeometry {
    static func isPickerBackdrop(_ frame: CGRect, display: CGRect) -> Bool {
        // Ignore small Dock hover labels and the backing window for only the tiled left half.
        frame.contains(display.insetBy(dx: 4, dy: 4))
    }

    static func pickerPoint(left: CGRect, preview: CGRect, display: CGRect) -> CGPoint? {
        guard abs(left.minX - display.minX) <= 4,
              left.height >= display.height - 90,
              left.minY >= display.minY - 4, left.maxY <= display.maxY + 4,
              left.width >= display.width * 0.1, left.width <= display.width * 0.9,
              preview.width >= 80, preview.height >= 60,
              preview.minX >= left.maxX, display.contains(preview) else { return nil }
        return CGPoint(x: preview.midX, y: preview.midY)
    }

    // A pair must cover one display, with adjacent edges and a narrow native divider.
    static func percentage(left: CGRect, right: CGRect, display: CGRect) -> Int? {
        let tolerance: CGFloat = 4
        let gap = right.minX - left.maxX
        guard left.width > 0, right.width > 0, gap >= 0, gap <= 24,
              abs(left.minX - display.minX) <= tolerance,
              abs(right.maxX - display.maxX) <= tolerance,
              coversFullscreenHeight(left, display: display),
              coversFullscreenHeight(right, display: display) else { return nil }
        return Int((left.width / (left.width + right.width) * 100).rounded())
    }

    private static func coversFullscreenHeight(_ frame: CGRect, display: CGRect) -> Bool {
        // Native fullscreen toolbars can be separate windows: one app's main AX/CG window
        // starts below its toolbar while its partner starts at the display's top edge.
        // Keep the existing 90-point top allowance, but validate BOTH windows independently.
        // Production still requires both AXFullScreen flags and both exact window IDs on screen.
        frame.minY >= display.minY - 4 && frame.height >= display.height - 90
            && abs(frame.maxY - display.maxY) <= 4
    }
}
