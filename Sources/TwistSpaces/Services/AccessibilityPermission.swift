// The legacy C header exposes the prompt key as a mutable global without concurrency annotations.
@preconcurrency import ApplicationServices

enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    // Only the explicit UI button calls this. No launch-time permission prompt.
    @MainActor
    static func requestFromUser() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
