import AppKit
import ApplicationServices
import OSLog

enum NewWindowError: String, LocalizedError {
    case permissionRequired, unavailable, unsupported, ambiguous, disabled, readFailed, unconfirmed
    var errorDescription: String? { L10n.text("launch.newError.\(rawValue)") }
}

enum NewWindowCommand {
    static func isStandardWindow(role: String?, subrole: String?) -> Bool {
        role == kAXWindowRole && subrole == kAXStandardWindowSubrole
    }

    static func matches(_ title: String) -> Bool {
        // External menu titles, not UI copy. Never guess from Cmd-N: it may create a file or thread.
        ["new window", "new empty window", "新建窗口", "新窗口", "新建空窗口"]
            .contains(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

// AX messaging stays off the UI actor, with bounded reads and exactly one action per request.
actor NewWindowService {
    static let shared = NewWindowService()
    private let inspector = WindowInspector()
    struct CapturedWindow {
        let application: ApplicationSnapshot
        let element: AXUIElement
        var windowID: CGWindowID? = nil
        var existingWindowIDs: Set<CGWindowID>? = nil
    }
    var capturedWindows: [NativeWindowToken: CapturedWindow] = [:]
    private var nextWindowToken = 1
    var splitInProgress = false

    func createWindow(in application: ApplicationSnapshot) async throws {
        let token = try await createWindowToken(in: application)
        release([token])
    }

    func createWindowToken(in application: ApplicationSnapshot) async throws -> NativeWindowToken {
        var phase = "permission"
        defer {
            #if DEBUG
            Logger(subsystem: "local.twist-spaces", category: "WindowOpening").notice("Create pid=\(application.pid) phase=\(phase, privacy: .public)")
            #endif
        }
        guard AccessibilityPermission.isTrusted else { throw NewWindowError.permissionRequired }
        guard await isCurrent(application) else { throw NewWindowError.unavailable }
        // Reuse the existing bounded Cursor compatibility recovery, without another permission prompt.
        let report = await inspector.inspect(application)
        phase = "inspect trusted=\(report.accessibilityTrusted) error=\(String(describing: report.windowsErrorCode)) count=\(report.windows.count)"
        guard report.accessibilityTrusted, report.windowsErrorCode == nil else { throw NewWindowError.readFailed }
        let app = AXUIElementCreateApplication(application.pid)
        guard AXUIElementSetMessagingTimeout(app, 0.5) == .success else { throw NewWindowError.readFailed }
        let before = try windows(of: app)
        phase = "menu beforeCount=\(before.count)"
        let command = try newWindowItem(in: app)
        phase = "activate"
        try await NewWindowExecution.prepare(isCurrent: {
            await self.isCurrent(application)
        }, activate: {
            await MainActor.run { NSRunningApplication(processIdentifier: application.pid)?.activate(options: []) ?? false }
        })
        // Snapshot before our single command: old windows may have identical frames, even off screen.
        let beforeWindowIDs = windowServerIDs(for: application.pid)
        let result = AXUIElementPerformAction(command, kAXPressAction as CFString)
        phase = "command result=\(result.rawValue)"
        // CannotComplete can mean the target handled the action but did not reply in time. Never retry it.
        guard result == .success || result == .cannotComplete else { throw NewWindowError.unconfirmed }
        for _ in 0..<20 {
            try await Task.sleep(for: .milliseconds(250))
            guard await isCurrent(application) else { throw NewWindowError.unavailable }
            if let current = try? windows(of: app) {
                let created = current.filter { candidate in !before.contains(where: { CFEqual($0, candidate) }) }
                phase = "observe beforeAX=\(before.count) currentAX=\(current.count) newAX=\(created.count) newCG=\(windowServerIDs(for: application.pid).subtracting(beforeWindowIDs).count)"
                guard created.count <= 1 else { throw NativeSplitError.ambiguousWindow }
                if let window = created.first {
                    let captured = CapturedWindow(application: application, element: window)
                    // AX and WindowServer publish a new window asynchronously. Preserve the creation
                    // snapshot even if its geometry is not ready yet; never issue another command.
                    let id = try? windowID(captured, excluding: beforeWindowIDs)
                    phase = "created id=\(String(describing: id))"
                    return capture(window, application: application, windowID: id, existingWindowIDs: beforeWindowIDs)
                }
                // Some apps expose their focused document before listing it in AXWindows.
                // Accept it only when it maps to one window created by this exact request.
                if let focused = NativeAX.element(app, kAXFocusedWindowAttribute) {
                    phase += " focusedRole=\(NativeAX.string(focused, kAXRoleAttribute) ?? "nil") focusedSubrole=\(NativeAX.string(focused, kAXSubroleAttribute) ?? "nil")"
                    let candidate = CapturedWindow(application: application, element: focused)
                    if NewWindowCommand.isStandardWindow(role: NativeAX.string(focused, kAXRoleAttribute),
                                                         subrole: NativeAX.string(focused, kAXSubroleAttribute)),
                       let id = try? windowID(candidate, excluding: beforeWindowIDs), !beforeWindowIDs.contains(id) {
                        phase = "created focused id=\(id)"
                        return capture(focused, application: application, windowID: id, existingWindowIDs: beforeWindowIDs)
                    }
                }
            } else {
                phase = "observe AXWindows read failed"
            }
        }
        throw NewWindowError.unconfirmed
    }

    func isCurrent(_ application: ApplicationSnapshot) async -> Bool {
        await MainActor.run {
            guard let running = NSRunningApplication(processIdentifier: application.pid) else { return false }
            return !running.isTerminated && running.bundleIdentifier == application.bundleIdentifier
                && running.bundleURL?.path == application.bundlePath
        }
    }

    private func capture(_ window: AXUIElement, application: ApplicationSnapshot, windowID: CGWindowID? = nil,
                         existingWindowIDs: Set<CGWindowID>? = nil) -> NativeWindowToken {
        let token = NativeWindowToken(value: nextWindowToken)
        nextWindowToken += 1
        capturedWindows[token] = CapturedWindow(application: application, element: window, windowID: windowID,
                                               existingWindowIDs: existingWindowIDs)
        return token
    }

    func captureFocusedWindow(in application: ApplicationSnapshot, requireSingle: Bool) async throws -> NativeWindowToken {
        let started = ContinuousClock.now
        var phase = "inspect"
        defer {
            #if DEBUG
            Logger(subsystem: "local.twist-spaces", category: "WindowOpening").notice("Capture pid=\(application.pid) phase=\(phase, privacy: .public) elapsed=\(String(describing: started.duration(to: .now)), privacy: .public)")
            #endif
        }
        guard AccessibilityPermission.isTrusted else { throw NewWindowError.permissionRequired }
        _ = await inspector.inspect(application)
        let app = AXUIElementCreateApplication(application.pid)
        _ = AXUIElementSetMessagingTimeout(app, 0.5)
        for attempt in 0..<20 {
            phase = "read attempt=\(attempt)"
            guard await isCurrent(application) else { throw NativeSplitError.windowMissing }
            let current = try windows(of: app)
            phase = "observe attempt=\(attempt) count=\(current.count)"
            #if DEBUG
            let focused = NativeAX.element(app, kAXFocusedWindowAttribute)
            let cgCount = windowServerIDs(for: application.pid).count
            Logger(subsystem: "local.twist-spaces", category: "WindowOpening").notice("Capture sample pid=\(application.pid) attempt=\(attempt) standardWindows=\(current.count) cgWindows=\(cgCount) focused=\(focused != nil) focusedRole=\(focused.flatMap { NativeAX.string($0, kAXRoleAttribute) } ?? "nil", privacy: .public) focusedSubrole=\(focused.flatMap { NativeAX.string($0, kAXSubroleAttribute) } ?? "nil", privacy: .public)")
            #endif
            if requireSingle, current.count > 1 { throw NativeSplitError.ambiguousWindow }
            if !requireSingle, let focused = NativeAX.element(app, kAXFocusedWindowAttribute),
               current.contains(where: { CFEqual($0, focused) }) {
                phase += " selected=focused"
                return capture(focused, application: application)
            }
            if current.count == 1 {
                phase += " selected=single"
                return capture(current[0], application: application)
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw NativeSplitError.ambiguousWindow
    }

    func release(_ tokens: [NativeWindowToken]) { for token in tokens { capturedWindows[token] = nil } }

    func matchedWindows(_ tokens: [NativeWindowToken]) async throws -> [MatchedWindow] {
        var elements: [AXUIElement] = []
        var matches: [MatchedWindow] = []
        for token in tokens {
            let window = try await validatedWindow(token)
            guard !elements.contains(where: { CFEqual($0, window.element) }) else {
                throw NativeSplitError.ambiguousWindow
            }
            elements.append(window.element)
            matches.append(MatchedWindow(applicationName: window.application.name,
                                         title: NativeAX.string(window.element, kAXTitleAttribute) ?? "",
                                         isFullscreen: NativeAX.bool(window.element, "AXFullScreen")))
        }
        #if DEBUG
        if tokens.count == 2, let left = capturedWindows[tokens[0]], let right = capturedWindows[tokens[1]] {
            traceMatchedPair(left, right)
        }
        #endif
        return matches
    }

    func validatedWindow(_ token: NativeWindowToken) async throws -> CapturedWindow {
        guard let captured = capturedWindows[token], await isCurrent(captured.application) else { throw NativeSplitError.windowMissing }
        let app = AXUIElementCreateApplication(captured.application.pid)
        _ = AXUIElementSetMessagingTimeout(app, 0.5)
        let listed = try windows(of: app).contains(where: { CFEqual($0, captured.element) })
        let focused = NativeAX.element(app, kAXFocusedWindowAttribute).map { CFEqual($0, captured.element) } == true
        guard listed || (captured.windowID != nil && focused) else { throw NativeSplitError.windowMissing }
        return captured
    }

    private func windows(of app: AXUIElement) throws -> [AXUIElement] {
        var raw: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw)
        guard result == .success, let windows = raw as? [AXUIElement] else {
            #if DEBUG
            Logger(subsystem: "local.twist-spaces", category: "WindowOpening").notice("AXWindows read failed code=\(result.rawValue) hasValue=\(raw != nil)")
            #endif
            throw NewWindowError.readFailed
        }
        let standard = windows.filter {
            NewWindowCommand.isStandardWindow(role: string(kAXRoleAttribute, of: $0), subrole: string(kAXSubroleAttribute, of: $0))
        }
        #if DEBUG
        if standard.isEmpty {
            let roles = windows.map { "\(NativeAX.string($0, kAXRoleAttribute) ?? "nil")/\(NativeAX.string($0, kAXSubroleAttribute) ?? "nil")" }.joined(separator: ",")
            Logger(subsystem: "local.twist-spaces", category: "WindowOpening").notice("AXWindows empty standard list rawCount=\(windows.count) roles=\(roles, privacy: .public)")
        }
        #endif
        return standard
    }

    private func newWindowItem(in app: AXUIElement) throws -> AXUIElement {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() else { throw NewWindowError.unsupported }
        // CF type identity was checked before this bridged cast.
        var queue: [(AXUIElement, Int)] = [(raw as! AXUIElement, 0)]
        var candidates: [AXUIElement] = []
        var index = 0
        let deadline = Date().addingTimeInterval(3)
        while index < queue.count && index < 400 && Date() < deadline {
            let (element, depth) = queue[index]
            index += 1
            if string(kAXRoleAttribute, of: element) == kAXMenuItemRole,
               let title = string(kAXTitleAttribute, of: element), NewWindowCommand.matches(title) {
                candidates.append(element)
            }
            // Only top-level menu commands qualify; do not descend into profiles or recent documents.
            if depth < 3 {
                var children: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
                   let children = children as? [AXUIElement] {
                    guard queue.count + children.count <= 400 else { throw NewWindowError.readFailed }
                    queue += children.map { ($0, depth + 1) }
                }
            }
        }
        #if DEBUG
        Logger(subsystem: "local.twist-spaces", category: "WindowOpening").notice("Menu visited=\(index) queued=\(queue.count) candidates=\(candidates.count)")
        #endif
        guard index == queue.count else { throw NewWindowError.readFailed }
        guard candidates.count <= 1 else { throw NewWindowError.ambiguous }
        guard let command = candidates.first else { throw NewWindowError.unsupported }
        var enabled: CFTypeRef?
        guard AXUIElementCopyAttributeValue(command, kAXEnabledAttribute as CFString, &enabled) == .success,
              (enabled as? NSNumber)?.boolValue == true else { throw NewWindowError.disabled }
        var actions: CFArray?
        guard AXUIElementCopyActionNames(command, &actions) == .success,
              (actions as? [String])?.contains(kAXPressAction) == true else { throw NewWindowError.unsupported }
        return command
    }

    private func string(_ attribute: String, of element: AXUIElement) -> String? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success else { return nil }
        return raw as? String
    }
}
