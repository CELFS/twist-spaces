import Foundation
import Testing
@testable import TwistSpaces

@Test func sameNameApplicationsRemainDistinct() {
    let first = ApplicationSnapshot(pid: 100, name: "Editor", bundleIdentifier: "example.editor", bundlePath: nil)
    let second = ApplicationSnapshot(pid: 101, name: "Editor", bundleIdentifier: "example.editor", bundlePath: nil)
    #expect(first.id != second.id)
}

@Test func reportPreservesUnicodeAndOptionalAttributeErrors() throws {
    let application = ApplicationSnapshot(
        pid: 100,
        name: "Editor",
        bundleIdentifier: "example.editor",
        bundlePath: "/Applications/Example Editor.app"
    )
    let report = DiagnosticReport(
        application: application,
        accessibilityTrusted: true,
        windowsErrorCode: nil,
        windows: [WindowSnapshot(
            ordinal: 1,
            supportedAttributes: ["AXTitle"],
            supportedAttributesErrorCode: nil,
            attributes: [
                AttributeObservation(name: "AXTitle", value: "Café — project", errorCode: nil),
                AttributeObservation(name: "AXDocument", value: nil, errorCode: -25205)
            ],
            buttons: []
        )]
    )

    let json = try DiagnosticJSON.string(from: report)
    let decoded = try JSONDecoder().decode(DiagnosticReport.self, from: Data(json.utf8))
    #expect(decoded.windows[0].attributes[0].value == "Café — project")
    #expect(decoded.windows[0].attributes[1].errorCode == -25205)
    #expect(decoded.windows[0].attributes[1].value == nil)
    #expect(decoded.application.bundlePath == application.bundlePath)
}

@Test func permissionBlockedIsDifferentFromAnEmptySuccessfulScan() throws {
    let application = ApplicationSnapshot(pid: 100, name: "Editor", bundleIdentifier: nil, bundlePath: nil)
    let blocked = DiagnosticReport(application: application, accessibilityTrusted: false, windowsErrorCode: nil, windows: [])
    let empty = DiagnosticReport(application: application, accessibilityTrusted: true, windowsErrorCode: nil, windows: [])
    #expect(try DiagnosticJSON.string(from: blocked) != DiagnosticJSON.string(from: empty))
}

@Test func englishResourcesAreAvailable() {
    #expect(L10n.text("app.name") == "Twist Spaces")
    #expect(L10n.text("cli.help").contains("--inspect PID"))
    #expect(L10n.text("diagnostics.copy") == "Copy complete diagnostic report")
    #expect(L10n.text("diagnostics.copied") == "Copied")
    #expect(L10n.text("diagnostics.copyFailed") == "Copy failed. Please try again.")
}

@Test func missingLocalizationKeysRemainVisible() {
    #expect(L10n.text("test.missing.key") == "test.missing.key")
}
