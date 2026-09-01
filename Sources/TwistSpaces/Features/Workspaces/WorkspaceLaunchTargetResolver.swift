import AppKit
import SwiftUI

struct WorkspaceLaunchTargetResolver {
    private let source: @MainActor () -> NativeDisplayTarget?

    init(source: @escaping @MainActor () -> NativeDisplayTarget?) {
        self.source = source
    }

    @MainActor
    func resolve() -> NativeDisplayTarget? { source() }
}

private struct WorkspaceLaunchTargetResolverKey: EnvironmentKey {
    static let defaultValue = WorkspaceLaunchTargetResolver {
        NativeDisplayTarget(screen: NSScreen.main)
    }
}

extension EnvironmentValues {
    var workspaceLaunchTargetResolver: WorkspaceLaunchTargetResolver {
        get { self[WorkspaceLaunchTargetResolverKey.self] }
        set { self[WorkspaceLaunchTargetResolverKey.self] = newValue }
    }
}
