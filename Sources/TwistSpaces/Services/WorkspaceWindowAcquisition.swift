import Foundation

struct WindowApplicationError: LocalizedError {
    let applicationName: String
    let reason: String
    var errorDescription: String? { "\(applicationName): \(reason)" }
}

// Behavior-based acquisition shared by all apps; no app names, repository commands, or new processes.
@MainActor
enum WorkspaceWindowAcquisition {
    static func acquire(
        action: WorkspaceOpenAction,
        isRunning: Bool,
        create: () async throws -> NativeWindowToken,
        openAndMatch: () async throws -> NativeWindowToken
    ) async throws -> NativeWindowToken {
        if action == .newWindows, isRunning {
            do { return try await create() }
            catch NewWindowError.unsupported {
                // No creation command was sent. The user permits opening/matching an existing window.
            } catch NewWindowError.disabled {
                // A disabled command is also known not to have created a window.
            }
            // Ambiguous commands, permission failures, and unconfirmed actions must not fall back.
        }
        try Task.checkCancellation()
        return try await openAndMatch()
    }
}
