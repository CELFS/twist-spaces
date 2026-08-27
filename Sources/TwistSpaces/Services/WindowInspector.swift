import ApplicationServices
import Foundation

// AX calls can block while another application responds. Keep them off the UI actor.
actor WindowInspector {
    func inspect(_ application: ApplicationSnapshot) -> DiagnosticReport {
        guard AccessibilityPermission.isTrusted else {
            return DiagnosticReport(
                application: application,
                accessibilityTrusted: false,
                windowsErrorCode: nil,
                windows: []
            )
        }

        let element = AXUIElementCreateApplication(application.pid)
        // This configures the AX client's messaging timeout; it does not modify a window.
        let timeoutError = AXUIElementSetMessagingTimeout(element, 1)
        guard timeoutError == .success else {
            return DiagnosticReport(
                application: application,
                accessibilityTrusted: true,
                windowsErrorCode: timeoutError.rawValue,
                windows: []
            )
        }

        var rawWindows: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &rawWindows)
        guard error == .success, let windows = rawWindows as? [AXUIElement] else {
            return DiagnosticReport(
                application: application,
                accessibilityTrusted: true,
                windowsErrorCode: error == .success ? AXError.failure.rawValue : error.rawValue,
                windows: []
            )
        }

        return DiagnosticReport(
            application: application,
            accessibilityTrusted: true,
            windowsErrorCode: nil,
            windows: windows.enumerated().map { index, window in
                inspectWindow(window, ordinal: index + 1)
            }
        )
    }

    private func inspectWindow(_ window: AXUIElement, ordinal: Int) -> WindowSnapshot {
        var names: CFArray?
        let namesError = AXUIElementCopyAttributeNames(window, &names)
        let attributes = [
            kAXTitleAttribute,
            kAXDocumentAttribute,
            kAXIdentifierAttribute,
            kAXRoleAttribute,
            kAXSubroleAttribute,
            kAXPositionAttribute,
            kAXSizeAttribute,
            kAXMinimizedAttribute
        ]
        var observations: [AttributeObservation] = []
        for attribute in attributes {
            observations.append(readAttribute(attribute as CFString, from: window))
        }
        var buttons: [ButtonObservation] = []
        for attribute in [kAXFullScreenButtonAttribute, kAXZoomButtonAttribute] {
            buttons.append(inspectButton(attribute as CFString, on: window))
        }

        return WindowSnapshot(
            ordinal: ordinal,
            supportedAttributes: names as? [String],
            supportedAttributesErrorCode: namesError == .success ? nil : namesError.rawValue,
            attributes: observations,
            buttons: buttons
        )
    }

    private func readAttribute(_ name: CFString, from element: AXUIElement) -> AttributeObservation {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name, &value)
        return AttributeObservation(
            name: name as String,
            value: error == .success ? value.flatMap(describeValue) : nil,
            errorCode: error == .success ? nil : error.rawValue
        )
    }

    private func describeValue(_ value: CFTypeRef) -> String? {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if let url = value as? URL { return url.absoluteString }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }

        // CF type identity was checked above before this bridged cast.
        let axValue = value as! AXValue
        switch AXValueGetType(axValue) {
        case .cgPoint:
            var point = CGPoint.zero
            guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
            return "\(point.x), \(point.y)"
        case .cgSize:
            var size = CGSize.zero
            guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
            return "\(size.width), \(size.height)"
        default:
            return nil
        }
    }

    private func inspectButton(_ attribute: CFString, on window: AXUIElement) -> ButtonObservation {
        var value: CFTypeRef?
        let lookupError = AXUIElementCopyAttributeValue(window, attribute, &value)
        guard lookupError == .success, let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return ButtonObservation(
                attribute: attribute as String,
                lookupErrorCode: lookupError == .success ? AXError.failure.rawValue : lookupError.rawValue,
                actions: nil,
                actionsErrorCode: nil
            )
        }

        // Listing button actions does not execute them or prove Split View can be paired.
        let button = value as! AXUIElement
        var actions: CFArray?
        let error = AXUIElementCopyActionNames(button, &actions)
        return ButtonObservation(
            attribute: attribute as String,
            lookupErrorCode: nil,
            actions: actions as? [String],
            actionsErrorCode: error == .success ? nil : error.rawValue
        )
    }
}
