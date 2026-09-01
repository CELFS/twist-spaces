import AppKit
import Combine
import SwiftUI

@MainActor
final class WorkspaceLaunchHUDController: NSWindowController {
    static let contentSize = CGSize(width: 528, height: 232)
    private let hostingController: NSHostingController<WorkspaceLaunchHUDView>
    private var progressObserver: AnyCancellable?

    init(model: WorkspaceViewModel) {
        let panel = WorkspaceLaunchHUDPanel(
            contentRect: CGRect(origin: .zero, size: Self.contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .utilityWindow
        let hostingController = NSHostingController(rootView: WorkspaceLaunchHUDView(progress: nil))
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hostingController
        panel.setContentSize(Self.contentSize)
        self.hostingController = hostingController
        super.init(window: panel)
        progressObserver = model.$launchProgress.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] progress in
            self?.update(progress)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(_ progress: WorkspaceLaunchProgress?) {
        guard let progress, let window, let screen = screen(for: progress.target.displayID) else {
            window?.orderOut(nil)
            return
        }
        hostingController.rootView = WorkspaceLaunchHUDView(progress: progress)
        window.setFrame(WorkspaceLaunchHUDGeometry.centeredFrame(contentSize: Self.contentSize,
                                                                visibleFrame: screen.visibleFrame), display: true)
        window.orderFrontRegardless()
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }
    }
}
