import Testing
@testable import TwistSpaces

@Test @MainActor func supportedWindowCreationRemainsPreferred() async throws {
    var matched = false
    let token = try await WorkspaceWindowAcquisition.acquire(action: .newWindows, isRunning: true, create: {
        NativeWindowToken(value: 1)
    }, openAndMatch: {
        matched = true
        return NativeWindowToken(value: 2)
    })
    #expect(token.value == 1)
    #expect(!matched)
}

@Test(arguments: [NewWindowError.unsupported, .disabled])
@MainActor func unavailableCreationOpensAndMatchesInstead(_ error: NewWindowError) async throws {
    var opens = 0
    let token = try await WorkspaceWindowAcquisition.acquire(action: .newWindows, isRunning: true, create: {
        throw error
    }, openAndMatch: {
        opens += 1
        return NativeWindowToken(value: 2)
    })
    #expect(token.value == 2)
    #expect(opens == 1)
}

@Test(arguments: [NewWindowError.permissionRequired, .unavailable, .ambiguous, .readFailed, .unconfirmed])
@MainActor func uncertainCreationNeverGuessesAnExistingWindow(_ error: NewWindowError) async {
    var opens = 0
    await #expect(throws: error) {
        try await WorkspaceWindowAcquisition.acquire(action: .newWindows, isRunning: true, create: {
            throw error
        }, openAndMatch: {
            opens += 1
            return NativeWindowToken(value: 2)
        })
    }
    #expect(opens == 0)
}

@Test @MainActor func stoppedAppsAndActivateUseSystemOpeningWithoutCreation() async throws {
    for (action, running) in [(WorkspaceOpenAction.newWindows, false), (.activate, true), (.activate, false)] {
        var creates = 0
        var opens = 0
        let token = try await WorkspaceWindowAcquisition.acquire(action: action, isRunning: running, create: {
            creates += 1
            return NativeWindowToken(value: 1)
        }, openAndMatch: {
            opens += 1
            return NativeWindowToken(value: 2)
        })
        #expect(token.value == 2)
        #expect(creates == 0)
        #expect(opens == 1)
    }
}

@Test @MainActor func fullscreenMatchesAreSuccessfulWithoutClaimingSplitApplied() {
    let matches = [MatchedWindow(applicationName: "Typora", title: "Notes", isFullscreen: false),
                   MatchedWindow(applicationName: "Sourcetree", title: "Sourcetree", isFullscreen: true)]
    let result = NativeWorkspaceOpening.preservedLayoutResult(matches)
    #expect(result == .windowsMatched(matches, .preserved))
    #expect(result?.succeeded == true)
    #expect(result?.hasMatchedWindows == true)
    #expect(result?.message.contains("Typora") == true)
    #expect(result?.message.contains("Notes") == true)
    #expect(result?.message.contains("Sourcetree") == true)
    #expect(result != .splitApplied(50))
    #expect(NativeWorkspaceOpening.preservedLayoutResult(Array(matches.suffix(1))) == nil)
}

@Test @MainActor func ordinaryWindowsStillRequireNativePairing() {
    let matches = [MatchedWindow(applicationName: "Left", title: "", isFullscreen: false),
                   MatchedWindow(applicationName: "Right", title: "", isFullscreen: false)]
    #expect(NativeWorkspaceOpening.preservedLayoutResult(matches) == nil)
    let result = WorkspaceLaunchResult.windowsMatched(matches, .failed("test-layout-error"))
    #expect(!result.succeeded)
    #expect(result.hasMatchedWindows)
    #expect(result.message.contains("Left"))
    #expect(result.message.contains("Right"))
    #expect(result.message.contains("test-layout-error"))
}
