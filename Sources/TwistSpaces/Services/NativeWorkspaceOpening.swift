import AppKit

@MainActor
enum NativeWorkspaceOpening {
    static func open(_ workspace: Workspace, urls: [String: URL], action: WorkspaceOpenAction) async throws -> WorkspaceLaunchResult {
        guard AccessibilityPermission.isTrusted else { throw NewWindowError.permissionRequired }
        let service = NewWindowService.shared
        var tokens: [NativeWindowToken] = []
        do {
            for application in workspace.applications {
                guard let url = urls[application.id] else { throw NativeSplitError.windowMissing }
                let running = NewWindowOperation().running(url)
                do {
                    let token = try await WorkspaceWindowAcquisition.acquire(action: action, isRunning: running != nil, create: {
                        guard let running else { throw NativeSplitError.windowMissing }
                        return try await service.createWindowToken(in: running)
                    }, openAndMatch: {
                        try await WorkspaceLauncher.openApplication(url)
                        guard let current = NewWindowOperation().running(url) else { throw NativeSplitError.windowMissing }
                        // A normal launch may restore several windows. Match the actual focused window,
                        // not an arbitrary first window or an assumption that one process has one window.
                        return try await service.captureFocusedWindow(in: current, requireSingle: false)
                    })
                    tokens.append(token)
                } catch {
                    throw WindowApplicationError(applicationName: application.name, reason: error.localizedDescription)
                }
            }
            let matches = try await service.matchedWindows(tokens)
            // Matching an existing fullscreen window is useful on its own. Do not dismantle or
            // resize an existing fullscreen combination just to satisfy this new layout request.
            if let preserved = preservedLayoutResult(matches) {
                await service.release(tokens)
                return preserved
            }
            let actual = try await service.applyNativeSplit(left: tokens[0], right: tokens[1], percentage: workspace.leftPercentage)
            await service.release(tokens)
            return .splitApplied(actual)
        } catch {
            // Report only windows that still validate now, not stale tokens or a guessed match.
            let matches = try? await service.matchedWindows(tokens)
            await service.release(tokens)
            if let matches, !matches.isEmpty {
                return .windowsMatched(matches, .failed(error.localizedDescription))
            }
            throw error
        }
    }

    static func preservedLayoutResult(_ matches: [MatchedWindow]) -> WorkspaceLaunchResult? {
        guard matches.count == 2, matches.contains(where: \.isFullscreen) else { return nil }
        return .windowsMatched(matches, .preserved)
    }
}
