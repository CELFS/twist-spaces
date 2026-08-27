import ApplicationServices
import AppKit
import Foundation

// AX calls can block while another application responds. Keep them off the UI actor.
actor WindowInspector {
    private var capturedElements: [Int32: [AXUIElement]] = [:]
    private var nextToken = 1
    private var liveWindows: [Int: (application: ApplicationSnapshot, element: AXUIElement, saved: SavedWindow)] = [:]

    func inspect(_ application: ApplicationSnapshot) async -> DiagnosticReport {
        await CursorAccessibility.inspect(application) {
            readWindows(application)
        } enable: {
            await enableCursorAccessibility(application)
        }
    }

    // This internal compatibility step only follows a successful but empty Cursor window read.
    private func enableCursorAccessibility(_ application: ApplicationSnapshot) async -> CursorAccessibilityResult {
        let currentApplication = await MainActor.run {
            ApplicationCatalog.runningApplications().first { $0.pid == application.pid }
        }
        return CursorAccessibility.enable(
            application,
            isTrusted: AccessibilityPermission.isTrusted,
            currentApplication: currentApplication
        ) {
            let element = AXUIElementCreateApplication(application.pid)
            let timeoutError = AXUIElementSetMessagingTimeout(element, 1)
            guard timeoutError == .success else { return timeoutError }
            // Electron's documented opt-in exposes accessibility information; it does not change window layout.
            return AXUIElementSetAttributeValue(element, CursorAccessibility.attribute as CFString, kCFBooleanTrue)
        }

    }

    private func readWindows(_ application: ApplicationSnapshot) -> DiagnosticReport {
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
            windows: capture(windows, application: application).enumerated().map { index, window in
                inspectWindow(window, ordinal: index + 1)
            }
        )
    }

    private func capture(_ windows: [AXUIElement], application: ApplicationSnapshot) -> [AXUIElement] {
        capturedElements[application.pid] = windows
        return windows
    }

    func workspaceWindows(_ applications: [ApplicationSnapshot]) async -> WindowScan {
        var choices: [WorkspaceWindow] = []
        var issues: [String] = []
        var current: [Int: (application: ApplicationSnapshot, element: AXUIElement, saved: SavedWindow)] = [:]
        for application in applications {
            capturedElements[application.pid] = nil
            let report = await inspect(application)
            guard report.accessibilityTrusted else {
                issues.append(L10n.text("workspace.error.permissionRequired"))
                break
            }
            guard report.windowsErrorCode == nil, let elements = capturedElements[application.pid] else {
                issues.append("\(application.name): \(L10n.text("workspace.scanFailed")) (\(report.windowsErrorCode ?? -1))")
                continue
            }
            guard let bundleIdentifier = application.bundleIdentifier, let bundlePath = application.bundlePath else { continue }
            if report.windows.isEmpty { issues.append("\(application.name): \(L10n.text("workspace.noWindows"))") }
            for (snapshot, element) in zip(report.windows, elements) {
                func value(_ name: String) -> String? {
                    snapshot.attributes.first { $0.name == name && $0.errorCode == nil }?.value.flatMap { $0.isEmpty ? nil : $0 }
                }
                guard value(kAXSubroleAttribute) == kAXStandardWindowSubrole else { continue }
                let saved = SavedWindow(
                    applicationName: application.name, bundleIdentifier: bundleIdentifier, bundlePath: bundlePath,
                    title: value(kAXTitleAttribute) ?? "", document: value(kAXDocumentAttribute), identifier: value(kAXIdentifierAttribute)
                )
                let previous = liveWindows.first { _, live in
                    live.application.pid == application.pid && live.saved.matches(saved) && CFEqual(live.element, element)
                }?.key
                let token = previous ?? nextToken
                if previous == nil { nextToken += 1 }
                current[token] = (application, element, saved)
                choices.append(WorkspaceWindow(id: token, saved: saved))
            }
        }
        liveWindows = current
        capturedElements.removeAll()
        return WindowScan(windows: choices, issues: issues)
    }

    func showWindows(tokens: [Int]) async throws {
        guard AccessibilityPermission.isTrusted else { throw WorkspaceError.permissionRequired }
        // Preflight the entire selection before changing any window. No title-based fallback here.
        let applications = await MainActor.run { ApplicationCatalog.runningApplications() }
        for token in tokens {
            guard let live = liveWindows[token], applications.contains(where: {
                $0.pid == live.application.pid && $0.bundleIdentifier == live.saved.bundleIdentifier && $0.bundlePath == live.saved.bundlePath
            }) else { throw WorkspaceError.windowUnavailable }
            let app = AXUIElementCreateApplication(live.application.pid)
            _ = AXUIElementSetMessagingTimeout(app, 1)
            var raw: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw) == .success,
                  let windows = raw as? [AXUIElement], windows.contains(where: { CFEqual($0, live.element) }) else {
                throw WorkspaceError.windowUnavailable
            }
            let title = readAttribute(kAXTitleAttribute as CFString, from: live.element)
            guard title.errorCode == nil, (title.value ?? "") == live.saved.title else { throw WorkspaceError.reselectWindow }
        }
        for token in tokens {
            guard let live = liveWindows[token] else { throw WorkspaceError.windowUnavailable }
            if readAttribute(kAXMinimizedAttribute as CFString, from: live.element).value == "1" {
                guard AXUIElementSetAttributeValue(live.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else {
                    throw WorkspaceError.windowOperationFailed
                }
            }
            guard AXUIElementPerformAction(live.element, kAXRaiseAction as CFString) == .success else {
                throw WorkspaceError.windowOperationFailed
            }
            let pid = live.application.pid
            let activated = await MainActor.run {
                NSRunningApplication(processIdentifier: pid)?.activate(options: []) ?? false
            }
            guard activated else { throw WorkspaceError.windowOperationFailed }
        }
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
