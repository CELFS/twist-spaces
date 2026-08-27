import Testing
@testable import TwistSpaces

@Test @MainActor func foregroundRejectionDoesNotSkipSecondApplicationsNewWindow() async throws {
    var events: [String] = []
    // The first app taking focus must not prevent the second app's validated menu action.
    for accepted in [true, false] {
        try await NewWindowExecution.prepare(isCurrent: { events.append("identity"); return true },
                                            activate: { events.append("activate"); return accepted })
        events.append("readyForMenuAction")
    }
    #expect(events == ["identity", "activate", "identity", "readyForMenuAction",
                       "identity", "activate", "identity", "readyForMenuAction"])
}

@Test @MainActor func exitedApplicationIsStillRejectedBeforeAnyAction() async {
    var actions = 0
    await #expect(throws: NewWindowError.unavailable) {
        try await NewWindowExecution.prepare(isCurrent: { false }, activate: { actions += 1; return true })
        actions += 1
    }
    #expect(actions == 0)
}

@Test @MainActor func processChangeDuringActivationPreventsMenuAction() async {
    var current = true
    var presses = 0
    await #expect(throws: NewWindowError.unavailable) {
        try await NewWindowExecution.prepare(isCurrent: { current }, activate: { current = false; return false })
        presses += 1
    }
    #expect(presses == 0)
}
