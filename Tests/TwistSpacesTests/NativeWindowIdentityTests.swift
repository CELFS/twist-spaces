import CoreGraphics
import Foundation
import Testing
@testable import TwistSpaces

@Test func windowIdentitySeparatesNewWindowFromIdenticalOldFrames() {
    let frame = CGRect(x: 359, y: 155, width: 640, height: 628)
    func entry(_ id: UInt32, pid: Int32 = 42, layer: Int = 0, bounds: CGRect? = nil) -> [String: Any] {
        [kCGWindowNumber as String: NSNumber(value: id), kCGWindowOwnerPID as String: NSNumber(value: pid),
         kCGWindowLayer as String: NSNumber(value: layer), kCGWindowBounds as String: (bounds ?? frame).dictionaryRepresentation]
    }
    let entries = [entry(10), entry(11), entry(12), entry(13, pid: 43), entry(14, layer: 20)]
    #expect(NativeWindowIdentity.matchingIDs(in: entries, pid: 42, frame: frame) == [10, 11, 12])
    #expect(NativeWindowIdentity.matchingIDs(in: entries, pid: 42, frame: frame, excluding: [10, 11]) == [12])
    // While WindowServer has not published the new window, do not substitute the old one.
    #expect(NativeWindowIdentity.matchingIDs(in: [entry(10)], pid: 42, frame: frame, excluding: [10]).isEmpty)
    // Two new same-sized candidates remain ambiguous; no first/last/title-based choice.
    #expect(NativeWindowIdentity.matchingIDs(in: entries, pid: 42, frame: frame, excluding: [10]) == [11, 12])
    #expect(NativeWindowIdentity.matchingIDs(in: [entry(12, bounds: frame.offsetBy(dx: 29, dy: 29))],
                                          pid: 42, frame: frame, excluding: [10, 11]).isEmpty)
}
