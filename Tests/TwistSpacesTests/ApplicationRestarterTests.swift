import AppKit
import Testing
@testable import TwistSpaces

@Test @MainActor func restartSchedulesRelaunchBeforeQuittingAndRejectsRepeatedClicks() {
    var calls: [String] = []
    let restarter = ApplicationRestarter(scheduleRelaunch: { calls.append("schedule") },
                                        terminate: { calls.append("terminate") },
                                        reportError: { _ in calls.append("error") })
    restarter.restart(nil)
    restarter.restart(nil)
    #expect(calls == ["schedule", "terminate"])
    #expect(restarter.isRestarting)
}

@Test @MainActor func failedRestartKeepsTheAppOpenAndAllowsRetry() {
    var attempts = 0
    var terminations = 0
    var errors = 0
    let restarter = ApplicationRestarter(scheduleRelaunch: {
        attempts += 1
        if attempts == 1 { throw CocoaError(.executableNotLoadable) }
    }, terminate: { terminations += 1 }, reportError: { _ in errors += 1 })
    restarter.restart(nil)
    #expect(!restarter.isRestarting)
    // Error reporting must finish without quitting the current app.
    #expect(terminations == 0)
    #expect(errors == 1)
    restarter.restart(nil)
    #expect(attempts == 2)
    #expect(terminations == 1)
    #expect(restarter.isRestarting)
}

@Test @MainActor func restartRejectsAMissingApplicationBundle() {
    #expect(throws: (any Error).self) {
        try ApplicationRestarter.scheduleRelaunch(applicationURL: URL(fileURLWithPath: "/missing/Twist Spaces.app"))
    }
}

@Test @MainActor func relaunchWaitsForExitAndPreservesTheExactApplicationPath() async throws {
    let parent = Process()
    let input = Pipe()
    parent.executableURL = URL(fileURLWithPath: "/bin/cat")
    parent.standardInput = input
    parent.standardOutput = FileHandle.nullDevice
    try parent.run()
    defer {
        try? input.fileHandleForWriting.close()
        if parent.isRunning { parent.terminate() }
    }

    let applicationURL = URL(fileURLWithPath: "/Applications/Twist 'Spaces' $(literal).app")
    // Echo records the arguments without opening an app or interacting with the desktop.
    let helper = ApplicationRestarter.makeRelaunchProcess(applicationURL: applicationURL,
                                                         processIdentifier: parent.processIdentifier,
                                                         openerURL: URL(fileURLWithPath: "/bin/echo"))
    let output = Pipe()
    helper.standardOutput = output
    try helper.run()
    defer { if helper.isRunning { helper.terminate() } }
    try await Task.sleep(for: .milliseconds(50))
    #expect(parent.isRunning)
    #expect(helper.isRunning)
    // Close the pipe to control the exact exit boundary, independent of test scheduling.
    try input.fileHandleForWriting.close()
    for _ in 0..<100 {
        if !helper.isRunning { break }
        try await Task.sleep(for: .milliseconds(20))
    }
    try #require(!helper.isRunning)
    #expect(!parent.isRunning)
    #expect(helper.terminationStatus == 0)
    #expect(String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) == applicationURL.path)
}
