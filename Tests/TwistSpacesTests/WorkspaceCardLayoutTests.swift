import AppKit
import SwiftUI
import Testing
@testable import TwistSpaces

@Test @MainActor func displayCombinationCardsStayCompact() throws {
    let left = SavedApplication(name: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92", bundlePath: "/Applications/Cursor.app")
    let right = SavedApplication(name: "ChatGPT (Codex)", bundleIdentifier: "com.openai.codex", bundlePath: "/Applications/Codex.app")
    let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/card-layout-previews")
    let model = WorkspaceViewModel(store: WorkspaceStore(url: output.appendingPathComponent("unused-workspaces.json")), catalog: { [] })
    for width in [300.0, 420.0] {
        for percentage in [10, 50, 90] {
            let workspace = Workspace(id: 1, name: "CC-1/2", projectPath: "", left: left.windowRecord,
                                      right: right.windowRecord, leftPercentage: percentage)
            let host = NSHostingView(rootView: WorkspaceCardView(workspace: workspace, model: model)
                .frame(width: width).fixedSize(horizontal: false, vertical: true)
                .background(Color(nsColor: .windowBackgroundColor)))
            #expect(abs(host.fittingSize.width - width) < 0.001)
            #expect(host.fittingSize.height <= 140)
            guard ProcessInfo.processInfo.environment["TWIST_CARD_PREVIEWS"] == "1" else { continue }
            host.setFrameSize(host.fittingSize)
            host.layoutSubtreeIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try #require(bitmap.representation(using: .png, properties: [:]))
                .write(to: output.appendingPathComponent("card-\(Int(width))-\(percentage).png"))
        }
    }
}
