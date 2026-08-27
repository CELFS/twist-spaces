import CoreGraphics
import Foundation

enum NativeWindowIdentity {
    static func matchingIDs(in entries: [[String: Any]], pid: pid_t, frame: CGRect,
                            excluding: Set<CGWindowID> = []) -> [CGWindowID] {
        entries.compactMap { entry in
            guard (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (entry[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let id = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  !excluding.contains(id),
                  let raw = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: raw),
                  abs(bounds.minX - frame.minX) <= 1, abs(bounds.minY - frame.minY) <= 1,
                  abs(bounds.width - frame.width) <= 1, abs(bounds.height - frame.height) <= 1 else { return nil }
            return id
        }
    }
}
