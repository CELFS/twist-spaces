import AppKit
import ApplicationServices

@MainActor
enum ProjectTagWindowDiscovery {
    private struct Candidate {
        let windowID: CGWindowID
        let frame: CGRect
        let projectName: String?
    }

    static func currentPairs() -> [ProjectTagLaunch] {
        guard AccessibilityPermission.isTrusted else { return [] }
        let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let windowEntries = entries.filter {
            ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
                && ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value != getpid()
        }
        let visiblePIDs = Set(windowEntries.compactMap {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
        })
        let applications = NSWorkspace.shared.runningApplications.filter {
            visiblePIDs.contains($0.processIdentifier) && $0.activationPolicy == .regular
        }
        var candidates: [Candidate] = []
        for application in applications {
            candidates += fullscreenWindows(application, entries: windowEntries)
        }
        return confirmedPairs(candidates)
    }

    private static func fullscreenWindows(_ application: NSRunningApplication,
                                          entries: [[String: Any]]) -> [Candidate] {
        let app = AXUIElementCreateApplication(application.processIdentifier)
        _ = AXUIElementSetMessagingTimeout(app, 0.2)
        guard let windows = NativeAX.value(app, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        let applicationName = application.localizedName ?? ""
        var usedIDs = Set<CGWindowID>()
        return windows.compactMap { window in
            guard NativeAX.string(window, kAXRoleAttribute) == kAXWindowRole,
                  NativeAX.string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole,
                  NativeAX.bool(window, "AXFullScreen"),
                  let frame = NativeAX.frame(window),
                  let windowID = exactWindowID(window, pid: application.processIdentifier,
                                               frame: frame, entries: entries),
                  usedIDs.insert(windowID).inserted,
                  let entry = entries.first(where: {
                      ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID
                  }), let visibleFrame = windowBounds(entry) else { return nil }
            let title = NativeAX.string(window, kAXTitleAttribute) ?? ""
            return Candidate(windowID: windowID, frame: visibleFrame,
                             projectName: ProjectTagNameResolver.projectName(
                                windowTitle: title, applicationName: applicationName
                             ))
        }
    }

    private static func exactWindowID(_ window: AXUIElement, pid: pid_t, frame: CGRect,
                                      entries: [[String: Any]]) -> CGWindowID? {
        if let number = NativeAX.value(window, "AXWindowNumber") as? NSNumber {
            let windowID = number.uint32Value
            if entries.contains(where: {
                ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
                    && ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID
            }) { return windowID }
        }
        let matches = NativeWindowIdentity.matchingIDs(in: entries, pid: pid, frame: frame)
        return matches.count == 1 ? matches[0] : nil
    }

    private static func confirmedPairs(_ candidates: [Candidate]) -> [ProjectTagLaunch] {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &displays, &count) == .success else { return [] }
        var results: [ProjectTagLaunch] = []
        var usedIDs = Set<CGWindowID>()
        for displayID in displays.prefix(Int(count)) {
            let display = CGDisplayBounds(displayID)
            let visible = candidates.filter { NativeSplitGeometry.isOnDisplay($0.frame, display: display) }
            let possible = visible.flatMap { left in
                visible.compactMap { right -> (Candidate, Candidate, Int)? in
                    guard left.windowID != right.windowID,
                          left.frame.minX < right.frame.minX,
                          let percentage = NativeSplitGeometry.percentage(
                            left: left.frame, right: right.frame, display: display
                          ) else { return nil }
                    return (left, right, percentage)
                }
            }.sorted { first, second in
                abs(first.2 - 50) < abs(second.2 - 50)
            }
            for (left, right, _) in possible where !usedIDs.contains(left.windowID) && !usedIDs.contains(right.windowID) {
                if let launch = ProjectTagLaunch(displayID: displayID,
                                                 leftWindowID: left.windowID, rightWindowID: right.windowID,
                                                 leftProjectName: left.projectName,
                                                 rightProjectName: right.projectName) {
                    results.append(launch)
                    usedIDs.insert(left.windowID)
                    usedIDs.insert(right.windowID)
                }
            }
        }
        return results
    }

    private static func windowBounds(_ entry: [String: Any]) -> CGRect? {
        guard let dictionary = entry[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary)
    }
}
