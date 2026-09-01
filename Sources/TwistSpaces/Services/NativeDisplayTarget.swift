import AppKit
import CoreGraphics

struct NativeDisplayTarget: Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let supportsIndependentSpaces: Bool

    init(displayID: CGDirectDisplayID, supportsIndependentSpaces: Bool) {
        self.displayID = displayID
        self.supportsIndependentSpaces = supportsIndependentSpaces
    }

    @MainActor
    init?(screen: NSScreen?) {
        guard let screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        self.init(displayID: number.uint32Value,
                  supportsIndependentSpaces: NSScreen.screens.count <= 1 || NSScreen.screensHaveSeparateSpaces)
    }

    func activeBounds() -> CGRect? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &displays, &count) == .success,
              displays.prefix(Int(count)).contains(displayID) else { return nil }
        return CGDisplayBounds(displayID)
    }
}
