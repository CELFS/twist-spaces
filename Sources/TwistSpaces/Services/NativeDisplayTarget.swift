import AppKit
import ApplicationServices
import CoreGraphics

struct NativeDisplayTarget: Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let supportsIndependentSpaces: Bool
    let startsFromSingleDisplayFullscreen: Bool

    init(displayID: CGDirectDisplayID, supportsIndependentSpaces: Bool,
         startsFromSingleDisplayFullscreen: Bool = false) {
        self.displayID = displayID
        self.supportsIndependentSpaces = supportsIndependentSpaces
        self.startsFromSingleDisplayFullscreen = startsFromSingleDisplayFullscreen
    }

    @MainActor
    init?(screen: NSScreen?) {
        guard let screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        let isSingleDisplay = NSScreen.screens.count <= 1
        self.init(displayID: number.uint32Value,
                  supportsIndependentSpaces: isSingleDisplay || NSScreen.screensHaveSeparateSpaces,
                  startsFromSingleDisplayFullscreen: isSingleDisplay && Self.frontmostWindowIsFullscreen())
    }

    @MainActor
    private static func frontmostWindowIsFullscreen() -> Bool {
        guard let application = NSWorkspace.shared.frontmostApplication else { return false }
        let element = AXUIElementCreateApplication(application.processIdentifier)
        _ = AXUIElementSetMessagingTimeout(element, 0.2)
        guard let window = NativeAX.element(element, kAXFocusedWindowAttribute) else { return false }
        return NativeAX.bool(window, "AXFullScreen")
    }

    func activeBounds() -> CGRect? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &displays, &count) == .success,
              displays.prefix(Int(count)).contains(displayID) else { return nil }
        return CGDisplayBounds(displayID)
    }
}
