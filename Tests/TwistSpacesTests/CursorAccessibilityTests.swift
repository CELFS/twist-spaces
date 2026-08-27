import ApplicationServices
import Foundation
import Testing
@testable import TwistSpaces

private let cursor = ApplicationSnapshot(
    pid: 123,
    name: "Cursor",
    bundleIdentifier: CursorAccessibility.bundleIdentifier,
    bundlePath: "/Applications/Cursor.app"
)

@Test func cursorAccessibilityRequiresTheExactBundleIdentifier() {
    #expect(CursorAccessibility.supports(cursor))
    let sameName = ApplicationSnapshot(pid: 123, name: "Cursor", bundleIdentifier: "example.editor", bundlePath: nil)
    #expect(!CursorAccessibility.supports(sameName))
    let missingIdentifier = ApplicationSnapshot(pid: 123, name: "Cursor", bundleIdentifier: nil, bundlePath: nil)
    #expect(!CursorAccessibility.supports(missingIdentifier))
}

@Test func enablingAccessibilityNeverWritesToAnotherApplication() {
    let other = ApplicationSnapshot(pid: 124, name: "Cursor", bundleIdentifier: "example.editor", bundlePath: nil)
    var writes = 0
    let result = CursorAccessibility.enable(other, isTrusted: true, currentApplication: other) {
        writes += 1
        return .success
    }
    #expect(writes == 0)
    #expect(result.status == .unsupportedApplication)
    #expect(result.errorCode == nil)
}

@Test func enablingAccessibilityRequiresExistingPermission() {
    var writes = 0
    let result = CursorAccessibility.enable(cursor, isTrusted: false, currentApplication: cursor) {
        writes += 1
        return .success
    }
    #expect(writes == 0)
    #expect(result.status == .permissionRequired)
    #expect(result.errorCode == nil)
}

@Test func enablingAccessibilityRejectsMissingOrChangedProcesses() {
    let replacements: [ApplicationSnapshot?] = [
        nil,
        ApplicationSnapshot(pid: 124, name: "Cursor", bundleIdentifier: cursor.bundleIdentifier, bundlePath: cursor.bundlePath),
        ApplicationSnapshot(pid: cursor.pid, name: "Other", bundleIdentifier: "example.other", bundlePath: cursor.bundlePath),
        ApplicationSnapshot(pid: cursor.pid, name: "Cursor", bundleIdentifier: cursor.bundleIdentifier, bundlePath: "/Applications/Other.app")
    ]
    for replacement in replacements {
        var writes = 0
        let result = CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: replacement) {
            writes += 1
            return .success
        }
        #expect(writes == 0)
        #expect(result.status == .applicationUnavailable)
        #expect(result.errorCode == nil)
    }
}

@Test func enablingAccessibilityWritesOnceAndRecordsSuccess() {
    var writes = 0
    let result = CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: cursor) {
        writes += 1
        return .success
    }
    #expect(writes == 1)
    #expect(result.attribute == "AXManualAccessibility")
    #expect(result.requestedValue)
    #expect(result.status == .succeeded)
    #expect(result.errorCode == 0)
}

@Test func enablingAccessibilityPreservesErrorsWithoutRetrying() {
    for error in [AXError.cannotComplete, .attributeUnsupported, .apiDisabled] {
        var writes = 0
        let result = CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: cursor) {
            writes += 1
            return error
        }
        #expect(writes == 1)
        #expect(result.status == .failed)
        #expect(result.errorCode == error.rawValue)
    }
}

@Test func accessibilityResultSurvivesAnEmptyWindowReport() throws {
    for error in [AXError.success, .cannotComplete] {
        var report = DiagnosticReport(application: cursor, accessibilityTrusted: true, windowsErrorCode: nil, windows: [])
        report.cursorAccessibility = CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: cursor) { error }
        let json = try DiagnosticJSON.string(from: report)
        let decoded = try JSONDecoder().decode(DiagnosticReport.self, from: Data(json.utf8))
        #expect(decoded.windows.isEmpty)
        #expect(decoded.cursorAccessibility?.errorCode == error.rawValue)
        #expect(decoded.cursorAccessibility?.attribute == "AXManualAccessibility")
        #expect(decoded.cursorAccessibility?.status == (error == .success ? .succeeded : .failed))
    }
}

@Test func reportsWithoutEnablementDoNotClaimAnAccessibilityRequest() throws {
    let report = DiagnosticReport(application: cursor, accessibilityTrusted: true, windowsErrorCode: nil, windows: [])
    let json = try DiagnosticJSON.string(from: report)
    #expect(!json.contains("cursorAccessibility"))
    let decoded = try JSONDecoder().decode(DiagnosticReport.self, from: Data(json.utf8))
    #expect(decoded.cursorAccessibility == nil)
}

@Test @MainActor func nonemptyWindowsAndMissingOptionalAttributesDoNotEnableAccessibility() async {
    let report = DiagnosticReport(application: cursor, accessibilityTrusted: true, windowsErrorCode: nil, windows: [
        WindowSnapshot(ordinal: 1, supportedAttributes: nil, supportedAttributesErrorCode: nil,
                       attributes: [AttributeObservation(name: "AXDocument", value: nil, errorCode: -25205)], buttons: [])
    ])
    var enables = 0
    var reads = 0
    let result = await CursorAccessibility.inspect(cursor) {
        reads += 1
        return report
    } enable: {
        enables += 1
        return CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: cursor) { .success }
    }
    #expect(reads == 1)
    #expect(enables == 0)
    #expect(result.windows.count == 1)
    #expect(result.cursorAccessibility == nil)
}

@Test @MainActor func unavailablePermissionAndFailedReadsDoNotEnableAccessibility() async {
    for report in [
        DiagnosticReport(application: cursor, accessibilityTrusted: false, windowsErrorCode: nil, windows: []),
        DiagnosticReport(application: cursor, accessibilityTrusted: true, windowsErrorCode: AXError.cannotComplete.rawValue, windows: [])
    ] {
        var enables = 0
        let result = await CursorAccessibility.inspect(cursor) { report } enable: {
            enables += 1
            return CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: cursor) { .success }
        }
        #expect(enables == 0)
        #expect(result.cursorAccessibility == nil)
    }
}

@Test @MainActor func anotherApplicationsEmptyListDoesNotEnableAccessibility() async {
    let other = ApplicationSnapshot(pid: 124, name: "Other", bundleIdentifier: "example.other", bundlePath: nil)
    var enables = 0
    let result = await CursorAccessibility.inspect(other) {
        DiagnosticReport(application: other, accessibilityTrusted: true, windowsErrorCode: nil, windows: [])
    } enable: {
        enables += 1
        return CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: cursor) { .success }
    }
    #expect(enables == 0)
    #expect(result.cursorAccessibility == nil)
}

@Test @MainActor func emptyCursorWindowsTriggerOnlyOneEnablementAndOneReread() async {
    var reads = 0
    var enables = 0
    let result = await CursorAccessibility.inspect(cursor) {
        reads += 1
        return DiagnosticReport(application: cursor, accessibilityTrusted: true, windowsErrorCode: nil, windows: [])
    } enable: {
        enables += 1
        return CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: cursor) { .success }
    }
    #expect(reads == 2)
    #expect(enables == 1)
    #expect(result.windows.isEmpty)
    #expect(result.cursorAccessibility?.status == .succeeded)
}

@Test @MainActor func failedEnablementDoesNotRetryOrDiscardItsError() async {
    var reads = 0
    var enables = 0
    let result = await CursorAccessibility.inspect(cursor) {
        reads += 1
        return DiagnosticReport(application: cursor, accessibilityTrusted: true, windowsErrorCode: nil, windows: [])
    } enable: {
        enables += 1
        return CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: cursor) { .cannotComplete }
    }
    #expect(reads == 1)
    #expect(enables == 1)
    #expect(result.cursorAccessibility?.errorCode == AXError.cannotComplete.rawValue)
}

@Test @MainActor func rereadPreservesTheEnablementResultAndNewWindows() async {
    var reads = 0
    let window = WindowSnapshot(ordinal: 1, supportedAttributes: nil, supportedAttributesErrorCode: nil, attributes: [], buttons: [])
    let result = await CursorAccessibility.inspect(cursor) {
        reads += 1
        return DiagnosticReport(application: cursor, accessibilityTrusted: true, windowsErrorCode: nil, windows: reads == 1 ? [] : [window])
    } enable: {
        CursorAccessibility.enable(cursor, isTrusted: true, currentApplication: cursor) { .success }
    }
    #expect(result.windows.count == 1)
    #expect(result.cursorAccessibility?.status == .succeeded)
}
