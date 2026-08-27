// Keep process validity, foreground activation, and verified window creation separate.
enum NewWindowExecution {
    static func prepare(
        isolation: isolated (any Actor)? = #isolation,
        isCurrent: () async -> Bool,
        activate: () async -> Bool
    ) async throws {
        guard await isCurrent() else { throw NewWindowError.unavailable }
        // A rejected foreground request does not mean the process exited. The validated AX command
        // can still create a window; only the subsequent window observation establishes success.
        _ = await activate()
        guard await isCurrent() else { throw NewWindowError.unavailable }
        try Task.checkCancellation()
    }
}
