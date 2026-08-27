import AppKit
import Testing
@testable import TwistSpaces

@Test @MainActor func copyingPreservesTheEntireReport() {
    // A private pasteboard keeps this test away from the user's general clipboard.
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let report = "{\n  \"windows\": [\n" + String(repeating: "    \"Café — project window\",\n", count: 2000) + "    \"last window\"\n  ]\n}\n"

    #expect(ReportClipboard.copy(report, to: pasteboard))
    #expect(pasteboard.string(forType: .string) == report)
}

@Test @MainActor func copyingAnEmptyReportPreservesExistingClipboardContent() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    #expect(pasteboard.setString("Existing clipboard content", forType: .string))

    #expect(!ReportClipboard.copy("", to: pasteboard))
    #expect(pasteboard.string(forType: .string) == "Existing clipboard content")
}

@Test @MainActor func copyingAReportReplacesPreviousClipboardText() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    #expect(pasteboard.setString("Previous report", forType: .string))

    #expect(ReportClipboard.copy("Current report", to: pasteboard))
    #expect(pasteboard.string(forType: .string) == "Current report")
}
