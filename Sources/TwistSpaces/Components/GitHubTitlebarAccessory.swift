import AppKit
import SwiftUI

@MainActor
final class GitHubTitlebarAccessory: NSTitlebarAccessoryViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
        layoutAttribute = .right
        let host = NSHostingView(rootView: GitHubLink().frame(width: 40, height: 28))
        host.sizingOptions = []
        host.frame = CGRect(x: 0, y: 0, width: 40, height: 28)
        view = host
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
