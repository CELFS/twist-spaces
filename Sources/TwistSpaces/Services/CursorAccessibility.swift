import ApplicationServices

enum CursorAccessibility {
    static let bundleIdentifier = "com.todesktop.230313mzl4w4u92"
    static let attribute = "AXManualAccessibility"

    static func supports(_ application: ApplicationSnapshot) -> Bool {
        application.bundleIdentifier == bundleIdentifier
    }

    static func inspect(
        _ application: ApplicationSnapshot,
        isolation: isolated (any Actor)? = #isolation,
        readWindows: () async -> DiagnosticReport,
        enable: () async -> CursorAccessibilityResult
    ) async -> DiagnosticReport {
        var report = await readWindows()
        // Missing optional window attributes do not justify changing accessibility support.
        guard supports(application), report.accessibilityTrusted,
              report.windowsErrorCode == nil, report.windows.isEmpty else { return report }

        let result = await enable()
        report.cursorAccessibility = result
        guard result.status == .succeeded else { return report }

        // Give Electron one short initialization interval, then read once without a retry loop.
        do {
            try await Task.sleep(for: .milliseconds(200))
        } catch {
            return report
        }
        report = await readWindows()
        report.cursorAccessibility = result
        return report
    }

    // The caller supplies a fresh process identity and the sole permitted AX write.
    // Keeping the checks before the closure also lets tests verify that rejected requests never write.
    static func enable(
        _ application: ApplicationSnapshot,
        isTrusted: Bool,
        currentApplication: ApplicationSnapshot?,
        setAttribute: () -> AXError
    ) -> CursorAccessibilityResult {
        let status: CursorAccessibilityResult.Status
        var errorCode: Int32?

        if !supports(application) {
            status = .unsupportedApplication
        } else if !isTrusted {
            status = .permissionRequired
        } else if let currentApplication,
                  currentApplication.pid == application.pid,
                  currentApplication.bundleIdentifier == application.bundleIdentifier,
                  currentApplication.bundlePath == application.bundlePath {
            let error = setAttribute()
            status = error == .success ? .succeeded : .failed
            errorCode = error.rawValue
        } else {
            status = .applicationUnavailable
        }

        return CursorAccessibilityResult(
            attribute: attribute,
            requestedValue: true,
            status: status,
            errorCode: errorCode
        )
    }
}
