import AppKit
import SwiftUI

@MainActor
final class ControlTitlebarAccessory: NSTitlebarAccessoryViewController {
    init(showPanel: @escaping () -> Void) {
        super.init(nibName: nil, bundle: nil)
        layoutAttribute = .right
        let host = NSHostingView(rootView: ControlTitlebarActions(showPanel: showPanel))
        host.sizingOptions = []
        host.frame = CGRect(x: 0, y: 0, width: 80, height: 28)
        view = host
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
