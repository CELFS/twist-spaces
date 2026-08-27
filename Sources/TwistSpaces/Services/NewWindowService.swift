import AppKit
import ApplicationServices

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

    func createWindow(in application: ApplicationSnapshot) async throws {
        guard AccessibilityPermission.isTrusted else { throw NewWindowError.permissionRequired }
        guard await isCurrent(application) else { throw NewWindowError.unavailable }
        // Reuse the existing bounded Cursor compatibility recovery, without another permission prompt.
        let report = await inspector.inspect(application)
        guard report.accessibilityTrusted, report.windowsErrorCode == nil else { throw NewWindowError.readFailed }
        let app = AXUIElementCreateApplication(application.pid)
        guard AXUIElementSetMessagingTimeout(app, 0.5) == .success else { throw NewWindowError.readFailed }
        let before = try windows(of: app)
        let command = try newWindowItem(in: app)
        guard await isCurrent(application) else { throw NewWindowError.unavailable }
        let activated = await MainActor.run { NSRunningApplication(processIdentifier: application.pid)?.activate(options: []) ?? false }
        guard activated else { throw NewWindowError.unavailable }
        let result = AXUIElementPerformAction(command, kAXPressAction as CFString)
        // CannotComplete can mean the target handled the action but did not reply in time. Never retry it.
        guard result == .success || result == .cannotComplete else { throw NewWindowError.unconfirmed }
        for _ in 0..<20 {
            try await Task.sleep(for: .milliseconds(250))
            guard await isCurrent(application) else { throw NewWindowError.unavailable }
            if let current = try? windows(of: app), current.contains(where: { candidate in
                !before.contains(where: { CFEqual($0, candidate) })
            }) { return }
        }
        throw NewWindowError.unconfirmed
    }

    private func isCurrent(_ application: ApplicationSnapshot) async -> Bool {
        await MainActor.run {
            guard let running = NSRunningApplication(processIdentifier: application.pid) else { return false }
            return !running.isTerminated && running.bundleIdentifier == application.bundleIdentifier
                && running.bundleURL?.path == application.bundlePath
        }
    }

    private func windows(of app: AXUIElement) throws -> [AXUIElement] {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement] else { throw NewWindowError.readFailed }
        return windows.filter {
            NewWindowCommand.isStandardWindow(role: string(kAXRoleAttribute, of: $0), subrole: string(kAXSubroleAttribute, of: $0))
        }
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
