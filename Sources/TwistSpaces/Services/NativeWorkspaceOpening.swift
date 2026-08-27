import AppKit

@MainActor
enum NativeWorkspaceOpening {
    static func open(_ workspace: Workspace, urls: [String: URL], action: WorkspaceOpenAction) async throws -> Int {
        guard AccessibilityPermission.isTrusted else { throw NewWindowError.permissionRequired }
        let service = NewWindowService.shared
        var tokens: [NativeWindowToken] = []
        do {
            for application in workspace.applications {
                guard let url = urls[application.id] else { throw NativeSplitError.windowMissing }
                let running = NewWindowOperation().running(url)
                if action == .newWindows, let running {
                    tokens.append(try await service.createWindowToken(in: running))
                } else {
                    try await WorkspaceLauncher.openApplication(url)
                    guard let current = NewWindowOperation().running(url) else { throw NativeSplitError.windowMissing }
                    tokens.append(try await service.captureFocusedWindow(in: current, requireSingle: running == nil))
                }
            }
            let actual = try await service.applyNativeSplit(left: tokens[0], right: tokens[1], percentage: workspace.leftPercentage)
            await service.release(tokens)
            return actual
        } catch {
            await service.release(tokens)
            throw error
        }
    }
}
