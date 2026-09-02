import AppKit
import ApplicationServices
import OSLog

// Native fullscreen tiling with target-display placement for exact newly created windows only:
// no AX size writes and no private Spaces APIs.
extension NewWindowService {
    func applyNativeSplit(left: NativeWindowToken, right: NativeWindowToken, percentage: Int,
                          target: NativeDisplayTarget? = nil,
                          minimumWindowAge: TimeInterval = WindowStabilityPolicy.defaultMinimumAge,
                          progress: WorkspaceLaunchPhaseHandler? = nil) async throws -> NativeSplitResult {
        let started = ContinuousClock.now
        var phase = "identify left"
        defer {
            #if DEBUG
            Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Split exit phase=\(phase, privacy: .public) elapsed=\(String(describing: started.duration(to: .now)), privacy: .public)")
            #endif
        }
        guard AccessibilityPermission.isTrusted else { throw NewWindowError.permissionRequired }
        guard !splitInProgress, (10...90).contains(percentage) else { throw NativeSplitError.cancelled }
        splitInProgress = true
        defer { splitInProgress = false }
        let first = try await identifiedWindow(left)
        phase = "identify right"
        let second = try await identifiedWindow(right)
        guard !CFEqual(first.element, second.element) else { throw NativeSplitError.ambiguousWindow }
        let leftID = try windowID(first)
        let rightID = try windowID(second)
        #if DEBUG
        Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Captured left pid=\(first.application.pid) id=\(leftID) right pid=\(second.application.pid) id=\(rightID) requested=\(percentage)")
        #endif

        let targetBounds = try target.map { target -> CGRect in
            guard target.supportsIndependentSpaces else { throw NativeSplitError.separateSpacesDisabled }
            guard let bounds = target.activeBounds() else { throw NativeSplitError.targetDisplayUnavailable }
            return bounds
        }
        let existingPair = confirmedPair(first, second, leftID: leftID, rightID: rightID)
        let pairIsOnTarget = existingPair.map { pair in
            guard let targetBounds else { return true }
            return NativeSplitGeometry.approximatelyEqual(pair.display, targetBounds)
        } == true
        var didStartTiling = false
        if pairIsOnTarget, targetBounds != nil {
            phase = "stabilize confirmed pair"
            for window in [first, second] where window.origin == .created {
                try await waitForStableWindow(window, minimumAge: minimumWindowAge)
            }
        }
        if !pairIsOnTarget {
            if let targetBounds {
                phase = "prepare target display"
                try await prepareForSplit([first, second], display: targetBounds,
                                          minimumWindowAge: minimumWindowAge, progress: progress)
            }
            // Never dismantle an existing fullscreen workspace to reuse one of its windows.
            guard !NativeAX.bool(first.element, "AXFullScreen"), !NativeAX.bool(second.element, "AXFullScreen") else {
                throw NativeSplitError.alreadyFullscreen
            }
            await progress?(.creatingSplit)
            phase = "focus left"
            try await focus(first)
            let visibleBeforeTiling = Set(windowEntries(onScreen: true).compactMap {
                ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value
            })
            phase = "enter left tile"
            didStartTiling = true
            do {
                try await enterLeftTile(first)
                phase = "select partner"
                try await selectPartner(second, windowID: rightID, beside: first, leftID: leftID,
                                        visibleBeforeTiling: visibleBeforeTiling)
            } catch {
                await rollbackCreatedFullscreenWindows([first, second])
                throw error
            }
        } else {
            await progress?(.creatingSplit)
        }
        phase = "confirm pair"
        do {
            for _ in 0..<30 {
                try Task.checkCancellation()
                if let pair = confirmedPair(first, second, leftID: leftID, rightID: rightID) {
                    #if DEBUG
                    Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Pair confirmed left=\(leftID) right=\(rightID) bothFullscreen=true sameDisplay=true actual=\(pair.percentage) requested=\(percentage)")
                    #endif
                    if abs(pair.percentage - percentage) <= 1 {
                        return nativeSplitResult(pair, leftID: leftID, rightID: rightID)
                    }
                    phase = "adjust ratio"
                    try await dragDivider(pair, percentage: percentage)
                    var confirmed: Pair?
                    for _ in 0..<15 {
                        try await Task.sleep(for: .milliseconds(100))
                        confirmed = confirmedPair(first, second, leftID: leftID, rightID: rightID)
                        if let confirmed, abs(confirmed.percentage - percentage) <= 1 {
                            #if DEBUG
                            Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Divider confirmed left=\(leftID) right=\(rightID) actual=\(confirmed.percentage) requested=\(percentage)")
                            #endif
                            return nativeSplitResult(confirmed, leftID: leftID, rightID: rightID)
                        }
                    }
                    if let confirmed { throw NativeSplitRatioError(requested: percentage, actual: confirmed.percentage) }
                    throw NativeSplitError.pairUnconfirmed
                }
                try await Task.sleep(for: .milliseconds(150))
            }
        } catch {
            let pairConfirmed = confirmedPair(first, second, leftID: leftID, rightID: rightID) != nil
            if NativeSplitRecovery.requiresRollback(didStartTiling: didStartTiling, pairConfirmed: pairConfirmed) {
                await rollbackCreatedFullscreenWindows([first, second])
            }
            throw error
        }
        if didStartTiling { await rollbackCreatedFullscreenWindows([first, second]) }
        throw NativeSplitError.pairUnconfirmed
    }

    func confirmedNativeSplit(left: NativeWindowToken, right: NativeWindowToken) async throws -> NativeSplitResult? {
        let first = try await identifiedWindow(left)
        let second = try await identifiedWindow(right)
        guard !CFEqual(first.element, second.element) else { throw NativeSplitError.ambiguousWindow }
        let leftID = try windowID(first)
        let rightID = try windowID(second)
        guard let pair = confirmedPair(first, second, leftID: leftID, rightID: rightID) else { return nil }
        return nativeSplitResult(pair, leftID: leftID, rightID: rightID)
    }

    private func rollbackCreatedFullscreenWindows(_ windows: [CapturedWindow]) async {
        let candidates = windows.filter {
            NativeSplitRecovery.shouldRestore(origin: $0.origin,
                                              isFullscreen: NativeAX.bool($0.element, "AXFullScreen"))
        }
        guard !candidates.isEmpty else { return }
        #if DEBUG
        Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Rolling back created fullscreen windows count=\(candidates.count)")
        #endif
        for window in candidates {
            try? setAttribute("AXFullScreen", value: kCFBooleanFalse, on: window.element)
        }
        // Fullscreen transitions are asynchronous. Observe only the flag here: the restored window
        // may land on a desktop Space that is no longer visible on the sole display.
        for _ in 0..<15 {
            if candidates.allSatisfy({ !NativeAX.bool($0.element, "AXFullScreen") }) { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func prepareForSplit(_ windows: [CapturedWindow], display: CGRect,
                                 minimumWindowAge: TimeInterval,
                                 progress: WorkspaceLaunchPhaseHandler?) async throws {
        let createdFullscreen = windows.filter {
            $0.origin == .created && NativeAX.bool($0.element, "AXFullScreen")
        }
        if !createdFullscreen.isEmpty {
            // A window created from an existing fullscreen Space can become fullscreen itself.
            // It may already be hidden after the next app opens, so normalize fullscreen before
            // the visibility-based stability check below.
            await progress?(.arrangingWindows)
            for window in createdFullscreen {
                try setAttribute("AXFullScreen", value: kCFBooleanFalse, on: window.element)
            }
            for window in createdFullscreen {
                try await waitUntilWindowed(window)
            }
        }
        // A new AX window can exist before an Electron or AppKit content tree is ready. Do not
        // take focus or enter fullscreen until its exact WindowServer identity has stayed stable.
        for window in windows where window.origin == .created {
            try await waitForStableWindow(window, requireWindowed: true, minimumAge: minimumWindowAge)
        }
        // Report the phase before the first state-changing AX write.
        await progress?(.arrangingWindows)
        for (index, window) in windows.enumerated() {
            guard let frame = NativeAX.frame(window.element) else { throw NativeSplitError.windowMissing }
            if !NativeSplitGeometry.isOnDisplay(frame, display: display) {
                guard window.origin == .created else { throw NativeSplitError.windowPlacementUnavailable }
                var point = NativeSplitGeometry.placementOrigin(frame, display: display, cascade: index)
                guard let value = AXValueCreate(.cgPoint, &point) else { throw NativeSplitError.windowPlacementUnavailable }
                try setAttribute(kAXPositionAttribute, value: value, on: window.element)
            }
            try await waitForStableWindow(window, display: display, requireWindowed: true)
        }
    }

    private func waitUntilWindowed(_ window: CapturedWindow) async throws {
        for _ in 0..<30 {
            try Task.checkCancellation()
            guard await isCurrent(window.application) else { throw NativeSplitError.windowMissing }
            if !NativeAX.bool(window.element, "AXFullScreen") { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw NativeSplitError.windowNotReady
    }

    private func setAttribute(_ attribute: String, value: CFTypeRef, on window: AXUIElement) throws {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(window, attribute as CFString, &settable) == .success,
              settable.boolValue else { throw NativeSplitError.windowPlacementUnavailable }
        let result = AXUIElementSetAttributeValue(window, attribute as CFString, value)
        // CannotComplete can mean the application applied the write but did not reply. Observe the
        // exact window instead of retrying a state-changing operation.
        guard result == .success || result == .cannotComplete else { throw NativeSplitError.windowPlacementUnavailable }
    }

    private func waitForStableWindow(_ window: CapturedWindow, display: CGRect? = nil,
                                     requireWindowed: Bool = false, minimumAge: TimeInterval = 0) async throws {
        guard let id = window.windowID else { throw NativeSplitError.ambiguousWindow }
        let app = AXUIElementCreateApplication(window.application.pid)
        _ = AXUIElementSetMessagingTimeout(app, 0.5)
        var previous: CGRect?
        var stableSamples = 0
        for _ in 0..<60 {
            try await Task.sleep(for: .milliseconds(150))
            try Task.checkCancellation()
            guard await isCurrent(window.application) else { throw NativeSplitError.windowMissing }
            let visible = windowEntries(onScreen: true).contains {
                ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id
                    && ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == window.application.pid
            }
            guard visible, let frame = NativeAX.frame(window.element), frame.width > 0, frame.height > 0,
                  !NativeAX.bool(app, kAXElementBusyAttribute),
                  !requireWindowed || !NativeAX.bool(window.element, "AXFullScreen"),
                  display.map({ NativeSplitGeometry.isOnDisplay(frame, display: $0) }) ?? true else {
                previous = nil
                stableSamples = 0
                continue
            }
            if let previous, NativeSplitGeometry.approximatelyEqual(previous, frame) { stableSamples += 1 }
            else { stableSamples = 1 }
            previous = frame
            if stableSamples >= 3, Date().timeIntervalSince(window.capturedAt) >= minimumAge { return }
        }
        throw NativeSplitError.windowNotReady
    }

    private func focus(_ window: CapturedWindow) async throws {
        let pid = window.application.pid
        _ = await MainActor.run { NSRunningApplication(processIdentifier: pid)?.activate(options: []) }
        let app = AXUIElementCreateApplication(window.application.pid)
        _ = AXUIElementSetMessagingTimeout(app, 0.5)
        _ = AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(window.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        _ = AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(window.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        for attempt in 0..<10 {
            #if DEBUG
            Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Focus pid=\(pid) attempt=\(attempt) frontmost=\(NativeAX.bool(app, kAXFrontmostAttribute)) focusedMatches=\(NativeAX.element(app, kAXFocusedWindowAttribute).map { CFEqual($0, window.element) } == true)")
            #endif
            // An app can remember a focused window while another app still owns the menu bar.
            if NativeAX.bool(app, kAXFrontmostAttribute),
               let focused = NativeAX.element(app, kAXFocusedWindowAttribute), CFEqual(focused, window.element) { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw NativeSplitError.focusFailed
    }

    private func enterLeftTile(_ window: CapturedWindow) async throws {
        var phase = "menu bar"
        defer {
            #if DEBUG
            Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Tile menu pid=\(window.application.pid) phase=\(phase, privacy: .public)")
            #endif
        }
        let app = AXUIElementCreateApplication(window.application.pid)
        _ = AXUIElementSetMessagingTimeout(app, 0.5)
        guard let bar = NativeAX.element(app, kAXMenuBarAttribute) else { throw NativeSplitError.menuUnavailable }
        let menus = NativeAX.children(bar).filter {
            ["Window", "窗口", "視窗"].contains(NativeAX.string($0, kAXTitleAttribute) ?? "")
        }
        phase = "window menu count=\(menus.count)"
        guard menus.count == 1 else { throw NativeSplitError.menuUnavailable }
        let menu = menus[0]
        phase = "press window menu"
        try NativeAX.press(menu)
        var commandSent = false
        defer {
            // Dismiss our own menu on failure; never send a global Escape to another app.
            if !commandSent { _ = AXUIElementPerformAction(menu, kAXCancelAction as CFString) }
        }
        var submenuOpened = false
        for attempt in 0..<12 {
            phase = "read commands attempt=\(attempt)"
            try await Task.sleep(for: .milliseconds(100))
            // Opening an Electron/native submenu validates and can replace its AX children.
            // Read fresh nodes and match actionable menu items, not identically titled containers.
            let nodes = try NativeAX.descendants(menu, depth: 5)
            let parents = nodes.filter {
                NativeAX.string($0.element, kAXRoleAttribute) == kAXMenuItemRole
                    && NativeSplitMenu.isTileMenu(NativeAX.string($0.element, kAXTitleAttribute) ?? "")
            }
            phase += " nodes=\(nodes.count) parents=\(parents.count)"
            guard parents.count <= 1 else { throw NativeSplitError.menuUnavailable }
            if !submenuOpened, let parent = parents.first {
                // AXPress executes a menu item; submenu disclosure is a pointer hover.
                // Pressing the parent can dismiss the native menu before its children validate.
                try NativeAX.revealSubmenu(parent.element)
                phase += " submenu revealed"
                submenuOpened = true
                continue
            }
            let candidates = nodes.filter {
                NativeAX.string($0.element, kAXRoleAttribute) == kAXMenuItemRole
                    && NativeSplitMenu.isLeftCommand(NativeAX.string($0.element, kAXTitleAttribute) ?? "", ancestors: $0.path)
                    && NativeAX.bool($0.element, kAXEnabledAttribute) && NativeAX.supportsPress($0.element)
            }
            phase += " enabledCommands=\(candidates.count)"
            guard candidates.count <= 1 else { throw NativeSplitError.menuUnavailable }
            guard let command = candidates.first else { continue }
            guard NativeAX.bool(app, kAXFrontmostAttribute),
                  let focused = NativeAX.element(app, kAXFocusedWindowAttribute), CFEqual(focused, window.element) else {
                throw NativeSplitError.focusFailed
            }
            try NativeAX.press(command.element)
            phase = "left tile command sent"
            commandSent = true
            return
        }
        throw NativeSplitError.menuUnavailable
    }

    private func selectPartner(_ window: CapturedWindow, windowID: CGWindowID, beside left: CapturedWindow,
                               leftID: CGWindowID, visibleBeforeTiling: Set<CGWindowID>) async throws {
        guard let dockPID = await MainActor.run(body: {
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        }) else { throw NativeSplitError.selectionUnavailable }
        var stableBounds: CGRect?
        for attempt in 0..<24 {
            try await Task.sleep(for: .milliseconds(125))
            try Task.checkCancellation()
            guard await isCurrent(window.application), await isCurrent(left.application) else { throw NativeSplitError.windowMissing }
            let entries = windowEntries(onScreen: true)
            #if DEBUG
            tracePartnerSelection(entries, leftID: leftID, rightID: windowID, rightPID: window.application.pid,
                                  dockPID: dockPID, previous: stableBounds, attempt: attempt,
                                  visibleBeforeTiling: visibleBeforeTiling)
            #endif
            // On the verified macOS 15.4.1 picker, preview bounds follow the original window IDs.
            // Dock's AX tree need not expose pressable previews; never infer identity from a title.
            guard let first = entries.first(where: {
                      ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == leftID
                          && ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == left.application.pid
                  }),
                  let second = entries.first(where: {
                      ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID
                          && ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == window.application.pid
                  }),
                  let leftBounds = bounds(of: first), let preview = bounds(of: second),
                  let display = displayContaining(leftBounds),
                  let point = NativeSplitGeometry.pickerPoint(left: leftBounds, preview: preview, display: display),
                  entries.contains(where: {
                      guard ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == dockPID,
                            let id = ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                            !visibleBeforeTiling.contains(id), let frame = bounds(of: $0) else { return false }
                      // The observed picker backdrop is layer -1; layer 20 may only be a hover label.
                      // Require a newly visible display-sized Dock backdrop, not any fixed layer.
                      return NativeSplitGeometry.isPickerBackdrop(frame, display: display)
                  }) else {
                stableBounds = nil
                continue
            }
            guard stableBounds == preview else { stableBounds = preview; continue }
            // Only click once the exact target thumbnail has stopped animating in the native picker.
            try NativeAX.clickPreview(at: point)
            #if DEBUG
            Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Partner click sent id=\(windowID) x=\(point.x) y=\(point.y)")
            #endif
            return
        }
        throw NativeSplitError.selectionUnavailable
    }

    #if DEBUG
    func traceMatchedPair(_ left: CapturedWindow, _ right: CapturedWindow) {
        let leftID = try? windowID(left)
        let rightID = try? windowID(right)
        traceMatchedWindow(left, id: leftID)
        traceMatchedWindow(right, id: rightID)
        if let leftID, let rightID {
            let percentage = confirmedPair(left, right, leftID: leftID, rightID: rightID)?.percentage
            Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Matched pair verified=\(percentage != nil) actual=\(percentage ?? -1)")
        }
    }

    // Inspect the existing matched windows without changing their layout or asking for screen capture.
    private func traceMatchedWindow(_ window: CapturedWindow, id: CGWindowID?) {
        var raw: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(window.element, "AXFullScreen" as CFString, &raw)
        let fullscreen = (raw as? NSNumber)?.stringValue ?? "unknown"
        let frame = String(describing: NativeAX.frame(window.element))
        let entries = windowEntries(onScreen: false).filter {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == window.application.pid
                && ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id
        }.map {
            "id=\($0[kCGWindowNumber as String] ?? "nil") visible=\($0[kCGWindowIsOnscreen as String] ?? "nil") layer=\($0[kCGWindowLayer as String] ?? "nil") bounds=\(String(describing: bounds(of: $0)))"
        }.joined(separator: "; ")
        Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("Matched pid=\(window.application.pid) fullscreen=\(fullscreen, privacy: .public) axError=\(error.rawValue) axFrame=\(frame, privacy: .public); \(entries, privacy: .public)")
    }

    // Numeric window metadata only: record each gate independently without changing picker behavior.
    // Read with: log show --last 10m --predicate 'subsystem == "local.twist-spaces" AND category == "NativeSplit"'
    private func tracePartnerSelection(_ entries: [[String: Any]], leftID: CGWindowID, rightID: CGWindowID,
                                       rightPID: pid_t, dockPID: pid_t, previous: CGRect?, attempt: Int,
                                       visibleBeforeTiling: Set<CGWindowID>) {
        let first = entries.first { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == leftID }
        let second = entries.first { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == rightID }
        let left = first.flatMap { bounds(of: $0) }
        let right = second.flatMap { bounds(of: $0) }
        let display = left.flatMap { displayContaining($0) }
        let point = left.flatMap { left in right.flatMap { right in display.flatMap {
            NativeSplitGeometry.pickerPoint(left: left, preview: right, display: $0)
        } } }
        let dock = entries.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == dockPID }
        var overlay = false
        if let point {
            for entry in dock where (entry[kCGWindowLayer as String] as? NSNumber)?.intValue == 20 {
                if bounds(of: entry)?.contains(point) == true { overlay = true }
            }
        }
        var newBackdrop = false
        if let display {
            for entry in dock {
                if let id = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                   !visibleBeforeTiling.contains(id), let frame = bounds(of: entry),
                   NativeSplitGeometry.isPickerBackdrop(frame, display: display) { newBackdrop = true }
            }
        }
        let windows = ([first, second].compactMap { $0 } + dock).map { entry in
            "id=\(entry[kCGWindowNumber as String] ?? "nil") pid=\(entry[kCGWindowOwnerPID as String] ?? "nil") layer=\(entry[kCGWindowLayer as String] ?? "nil") bounds=\(String(describing: bounds(of: entry)))"
        }.joined(separator: "; ")
        let gates = "attempt=\(attempt) leftFound=\(first != nil) rightFound=\(second != nil) rightOwner=\((second?[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == rightPID) display=\(String(describing: display)) geometry=\(point != nil) newBackdrop=\(newBackdrop) dockLayer20=\(overlay) stable=\(right != nil && previous == right)"
        Logger(subsystem: "local.twist-spaces", category: "NativeSplit").notice("\(gates, privacy: .public); \(windows, privacy: .public)")
    }
    #endif

    private func bounds(of entry: [String: Any]) -> CGRect? {
        guard let value = entry[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: value)
    }

    private func displayContaining(_ frame: CGRect) -> CGRect? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &displays, &count) == .success else { return nil }
        for id in displays.prefix(Int(count)) {
            let display = CGDisplayBounds(id)
            if display.contains(CGPoint(x: frame.midX, y: frame.midY)) {
                return display
            }
        }
        return nil
    }

    func windowServerIDs(for pid: pid_t) -> Set<CGWindowID> {
        Set(windowEntries(onScreen: false).compactMap {
            guard ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid else { return nil }
            return ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        })
    }

    private func identifiedWindow(_ token: NativeWindowToken) async throws -> CapturedWindow {
        for attempt in 0..<20 {
            try Task.checkCancellation()
            let window = try await validatedWindow(token)
            do {
                let identified = CapturedWindow(application: window.application, element: window.element,
                                                origin: window.origin, capturedAt: window.capturedAt,
                                                windowID: try windowID(window), existingWindowIDs: window.existingWindowIDs)
                capturedWindows[token] = identified
                return identified
            } catch {
                guard window.windowID == nil, attempt < 19 else { throw error }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        throw NativeSplitError.ambiguousWindow
    }

    func windowID(_ window: CapturedWindow, excluding: Set<CGWindowID> = []) throws -> CGWindowID {
        let excluding = window.existingWindowIDs ?? excluding
        let entries = windowEntries(onScreen: false).filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == window.application.pid }
        if let id = window.windowID {
            // Identity was bound while creating this exact AX window, before another app took focus.
            // A missing ID is stale, not permission to select a different same-sized window.
            guard entries.contains(where: { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == id }) else {
                throw NativeSplitError.windowMissing
            }
            return id
        }
        if let number = NativeAX.value(window.element, "AXWindowNumber") as? NSNumber,
           entries.contains(where: { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == number.uint32Value }) {
            return number.uint32Value
        }
        guard let frame = NativeAX.frame(window.element) else { throw NativeSplitError.windowMissing }
        let matches = NativeWindowIdentity.matchingIDs(in: entries, pid: window.application.pid, frame: frame, excluding: excluding)
        #if DEBUG
        if !excluding.isEmpty || matches.count != 1 {
            let all = NativeWindowIdentity.matchingIDs(in: entries, pid: window.application.pid, frame: frame)
            Logger(subsystem: "local.twist-spaces", category: "WindowOpening").notice("WindowID pid=\(window.application.pid) allMatches=\(all.count) newMatches=\(matches.count) excluded=\(excluding.count)")
        }
        #endif
        guard matches.count == 1 else {
            throw NativeSplitError.ambiguousWindow
        }
        return matches[0]
    }

    private func windowEntries(onScreen: Bool) -> [[String: Any]] {
        // Window metadata only; no screen capture and no recording permission request.
        CGWindowListCopyWindowInfo(onScreen ? [.optionOnScreenOnly, .excludeDesktopElements] : [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    }

    private struct Pair {
        let left: CGRect
        let right: CGRect
        let display: CGRect
        let displayID: CGDirectDisplayID
        let percentage: Int
    }

    private func nativeSplitResult(_ pair: Pair, leftID: CGWindowID, rightID: CGWindowID) -> NativeSplitResult {
        NativeSplitResult(percentage: pair.percentage, displayID: pair.displayID,
                          leftWindowID: leftID, rightWindowID: rightID)
    }

    private func confirmedPair(_ left: CapturedWindow, _ right: CapturedWindow, leftID: CGWindowID, rightID: CGWindowID) -> Pair? {
        guard NativeAX.bool(left.element, "AXFullScreen"), NativeAX.bool(right.element, "AXFullScreen"),
              let first = NativeAX.frame(left.element), let second = NativeAX.frame(right.element) else { return nil }
        let visible = Set(windowEntries(onScreen: true).compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
        guard visible.contains(leftID), visible.contains(rightID) else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &displays, &count) == .success else { return nil }
        for id in displays.prefix(Int(count)) {
            let bounds = CGDisplayBounds(id)
            if let percentage = NativeSplitGeometry.percentage(left: first, right: second, display: bounds) {
                return Pair(left: first, right: second, display: bounds, displayID: id, percentage: percentage)
            }
        }
        return nil
    }

    private func dragDivider(_ pair: Pair, percentage: Int) async throws {
        // Adjust the already-confirmed native divider, never resize normal desktop windows.
        guard CGPreflightPostEventAccess() else { throw NewWindowError.permissionRequired }
        let gap = pair.right.minX - pair.left.maxX
        let start = CGPoint(x: pair.left.maxX + gap / 2, y: pair.left.midY)
        let end = CGPoint(x: pair.display.minX + (pair.display.width - gap) * CGFloat(percentage) / 100 + gap / 2, y: start.y)
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left),
              let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: start, mouseButton: .left) else {
            throw NativeSplitError.ratioUnavailable
        }
        guard !CGEventSource.buttonState(.combinedSessionState, button: .left) else { throw NativeSplitError.cancelled }
        move.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(80))
        try Task.checkCancellation()
        guard let pointer = CGEvent(source: nil)?.location,
              abs(pointer.x - start.x) <= 2, abs(pointer.y - start.y) <= 2,
              !CGEventSource.buttonState(.combinedSessionState, button: .left) else { throw NativeSplitError.cancelled }
        down.post(tap: .cghidEventTap)
        defer { up.post(tap: .cghidEventTap) }
        for step in 1...12 {
            let position = CGPoint(x: start.x + (end.x - start.x) * CGFloat(step) / 12, y: start.y)
            guard let drag = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: position, mouseButton: .left) else {
                throw NativeSplitError.ratioUnavailable
            }
            drag.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(16))
        }
    }
}
