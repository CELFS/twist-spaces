import AppKit
import SwiftUI
import Testing
@testable import TwistSpaces

@Test @MainActor func panelScrollViewportExcludesQuickLaunchAndFooter() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/panel-scroll-\(ProcessInfo.processInfo.globallyUniqueString)")
    let store = WorkspaceStore(url: root.appendingPathComponent("workspaces.json"))
    let application = SavedApplication(name: "TextEdit", bundleIdentifier: "com.apple.TextEdit",
                                       bundlePath: "/System/Applications/TextEdit.app")
    var library = WorkspaceLibrary()
    library.nextID = 9
    library.workspaces = (1...8).map {
        Workspace(id: $0, name: "Combination \($0)", projectPath: "", left: application.windowRecord, right: application.windowRecord)
    }
    try store.save(library)
    defer { try? FileManager.default.removeItem(at: root) }
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = PanelSettings(defaults: defaults)
    let model = WorkspaceViewModel(store: store, catalog: { [] })
    let host = NSHostingView(rootView: WorkspacePanelView(model: model, panelSettings: settings, close: {}, settings: {})
        .frame(width: 460, height: 480))
    host.setFrameSize(CGSize(width: 460, height: 480))
    host.layoutSubtreeIfNeeded()

    func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }
    let scrolls = scrollViews(in: host)
    #expect(scrolls.count == 1)
    let scroll = try #require(scrolls.first)
    let frame = scroll.convert(scroll.bounds, to: host)
    let topInset = host.isFlipped ? frame.minY : host.bounds.maxY - frame.maxY
    let bottomInset = host.isFlipped ? host.bounds.maxY - frame.maxY : frame.minY
    #expect(topInset > 140)
    #expect(bottomInset > 40)
    // An offscreen host need not materialize LazyVStack's document yet; verify its viewport,
    // whose bounds used to include Quick Launch, independently of lazy content realization.
    #expect(frame.height > 150)
}
