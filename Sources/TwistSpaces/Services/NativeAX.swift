import ApplicationServices
import Foundation

// Public Accessibility operations. Window objects stay inside NewWindowService's actor.
enum NativeAX {
    static func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    static func string(_ element: AXUIElement, _ name: String) -> String? { value(element, name) as? String }
    static func bool(_ element: AXUIElement, _ name: String) -> Bool { (value(element, name) as? NSNumber)?.boolValue == true }
    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let result = value(element, name), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }
    static func children(_ element: AXUIElement) -> [AXUIElement] {
        value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
    static func supportsPress(_ element: AXUIElement) -> Bool {
        var names: CFArray?
        return AXUIElementCopyActionNames(element, &names) == .success
            && (names as? [String])?.contains(kAXPressAction) == true
    }
    static func press(_ element: AXUIElement) throws {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        guard result == .success || result == .cannotComplete else { throw NativeSplitError.selectionUnavailable }
    }
    static func revealSubmenu(_ element: AXUIElement) throws {
        guard CGPreflightPostEventAccess() else { throw NewWindowError.permissionRequired }
        guard let bounds = frame(element), bounds.width > 0, bounds.height > 0,
              !CGEventSource.buttonState(.combinedSessionState, button: .left),
              let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                  mouseCursorPosition: CGPoint(x: bounds.midX, y: bounds.midY), mouseButton: .left) else {
            throw NativeSplitError.menuUnavailable
        }
        // Coordinates come from the open native menu item, never from a fixed screen offset.
        event.post(tap: .cghidEventTap)
    }
    static func clickPreview(at point: CGPoint) throws {
        guard CGPreflightPostEventAccess() else { throw NewWindowError.permissionRequired }
        guard !CGEventSource.buttonState(.combinedSessionState, button: .left),
              let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            throw NativeSplitError.selectionUnavailable
        }
        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 1)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let rawPosition = value(element, kAXPositionAttribute), let rawSize = value(element, kAXSizeAttribute),
              CFGetTypeID(rawPosition) == AXValueGetTypeID(), CFGetTypeID(rawSize) == AXValueGetTypeID() else { return nil }
        let position = rawPosition as! AXValue
        let size = rawSize as! AXValue
        guard AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
    static func descendants(_ root: AXUIElement, depth: Int = 6) throws -> [(element: AXUIElement, path: [String])] {
        var queue: [(AXUIElement, [String], Int)] = [(root, [], 0)]
        var result: [(AXUIElement, [String])] = []
        var index = 0
        let deadline = Date().addingTimeInterval(2)
        while index < queue.count {
            guard index < 800, Date() < deadline else { throw NativeSplitError.selectionUnavailable }
            let (element, ancestors, level) = queue[index]
            index += 1
            let labels = [kAXTitleAttribute, kAXDescriptionAttribute].compactMap { string(element, $0) }
            result.append((element, ancestors))
            if level < depth {
                let next = children(element)
                guard queue.count + next.count <= 800 else { throw NativeSplitError.selectionUnavailable }
                queue += next.map { ($0, ancestors + labels, level + 1) }
            }
        }
        return result
    }
}
