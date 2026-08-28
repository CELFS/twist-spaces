import AppKit
import Foundation
import SwiftUI
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
    #expect(L10n.text("app.name", language: .english) == "Twist Spaces")
    #expect(L10n.text("cli.help", language: .english).contains("--inspect PID"))
    #expect(L10n.text("diagnostics.copy", language: .english) == "Copy complete diagnostic report")
    #expect(L10n.text("diagnostics.copied", language: .english) == "Copied")
    #expect(L10n.text("diagnostics.copyFailed", language: .english) == "Copy failed. Please try again.")
}

@Test func missingLocalizationKeysRemainVisible() {
    #expect(L10n.text("test.missing.key") == "test.missing.key")
}

@Test @MainActor func diagnosticsWindowRemainsCenteredAfterLayoutAndReopening() async throws {
    let controller = DiagnosticsWindowController()
    let window = try #require(controller.window)
    defer { window.close() }
    controller.showWindow(nil)
    let presentedFrame = window.frame
    // Allow the real SwiftUI content to finish its first layout before checking position.
    try await Task.sleep(for: .milliseconds(150))
    let screen = try #require(window.screen)
    #expect(window.frame == presentedFrame)
    #expect(window.contentRect(forFrameRect: window.frame).size == NSSize(width: 602, height: 434))
    #expect(abs(window.frame.midX - screen.visibleFrame.midX) < 1)
    #expect(screen.visibleFrame.contains(window.frame))

    if ProcessInfo.processInfo.environment["TWIST_DIAGNOSTICS_PREVIEWS"] == "1" {
        let view = NSHostingView(rootView: DiagnosticsView().frame(width: 602, height: 434)
            .background(Color(nsColor: .windowBackgroundColor)))
        view.setFrameSize(NSSize(width: 602, height: 434))
        view.layoutSubtreeIfNeeded()
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/diagnostics-602x434.png")
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: output)
    }

    window.setContentSize(NSSize(width: 800, height: 560))
    try await Task.sleep(for: .milliseconds(150))
    let resizedSize = window.frame.size
    window.setFrameOrigin(CGPoint(x: screen.visibleFrame.maxX - resizedSize.width, y: screen.visibleFrame.minY))
    window.close()
    controller.showWindow(nil)
    try await Task.sleep(for: .milliseconds(150))
    #expect(window.frame.size == resizedSize)
    #expect(abs(window.frame.midX - screen.visibleFrame.midX) < 1)
    #expect(screen.visibleFrame.contains(window.frame))
}
