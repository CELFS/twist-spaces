enum NativeSplitRecovery {
    static func requiresRollback(didStartTiling: Bool, pairConfirmed: Bool) -> Bool {
        didStartTiling && !pairConfirmed
    }

    static func shouldRestore(origin: NativeWindowOrigin, isFullscreen: Bool) -> Bool {
        origin == .created && isFullscreen
    }
}
