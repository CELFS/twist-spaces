import AppKit
import SwiftUI
import Testing
@testable import TwistSpaces

@Test @MainActor func brandingCopyAndRepositoryAreAvailableInBothLanguages() {
    #expect(L10n.text("action.quit", language: .english) == "Quit")
    #expect(L10n.text("action.quit", language: .simplifiedChinese) == "退出")
    for key in ["about.title", "about.version", "about.copyright", "about.github", "control.layoutPanel"] {
        for language in [AppLanguage.english, .simplifiedChinese] {
            #expect(L10n.text(key, language: language) != key)
        }
    }
    #expect(GitHubLink.repositoryURL.absoluteString == "https://github.com/CELFS/twist-spaces")
}

@Test @MainActor func bundledWhiteLogoRendersWithTransparentBackgroundAndWhiteArtwork() throws {
    let url = try #require(AppResources.bundle.url(forResource: "AppLogoWhiteMask", withExtension: "png"))
    #expect(NSImage(contentsOf: url) != nil)
    let renderer = ImageRenderer(content: AppLogoView(size: 256, monochrome: true).environment(\.colorScheme, .dark))
    let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    #expect(bitmap.hasAlpha)
    #expect(bitmap.pixelsWide >= 256)
    #expect(bitmap.pixelsHigh >= 256)
    var transparent = 0
    var opaque = 0
    for y in stride(from: 0, to: bitmap.pixelsHigh, by: 17) {
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 17) {
            let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
            if color.alphaComponent < 0.01 { transparent += 1 }
            else {
                #expect(abs(color.redComponent - 1) < 0.01)
                #expect(abs(color.greenComponent - 1) < 0.01)
                #expect(abs(color.blueComponent - 1) < 0.01)
                if color.alphaComponent > 0.99 { opaque += 1 }
            }
        }
    }
    #expect(transparent > 100)
    #expect(opaque > 30)
    let colorURL = try #require(AppResources.bundle.url(forResource: "AppLogo", withExtension: "png"))
    #expect(NSImage(contentsOf: colorURL) != nil)
}

@Test @MainActor func brandedPanelAndControlCenterFitTheirSupportedWidths() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/branding-previews")
    let model = WorkspaceViewModel(store: WorkspaceStore(url: root.appendingPathComponent("unused-workspaces.json")), catalog: { [] })
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = PanelSettings(defaults: defaults)
    let controller = WorkspaceControlController(model: model, settings: settings, showPanel: {})
    let window = try #require(controller.window)
    let accessory = try #require(window.titlebarAccessoryViewControllers.first as? ControlTitlebarAccessory)
    #expect(window.titlebarAccessoryViewControllers.count == 1)
    #expect(accessory.layoutAttribute == .right)
    #expect(accessory.view.frame.width == 80)

    func check<V: View>(_ view: V, width: CGFloat, height: CGFloat, name: String) throws {
        let host = NSHostingView(rootView: view.frame(width: width, height: height)
            .background(Color(nsColor: .windowBackgroundColor)))
        host.setFrameSize(CGSize(width: width, height: height))
        host.layoutSubtreeIfNeeded()
        #expect(abs(host.fittingSize.width - width) < 1)
        #expect(abs(host.fittingSize.height - height) < 1)
        guard ProcessInfo.processInfo.environment["TWIST_BRANDING_PREVIEWS"] == "1" else { return }
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: root.appendingPathComponent("\(name).png"))
    }

    for width in [300.0, 460.0, 700.0] {
        try check(WorkspacePanelView(model: model, panelSettings: settings, close: {}, settings: {}),
                  width: width, height: 700, name: "panel-\(Int(width))")
    }
    for width in [801.0, 920.0] {
        try check(WorkspaceControlView(model: model, settings: settings, showPanel: {}),
                  width: width, height: 540, name: "control-\(Int(width))")
    }
    for scheme in [ColorScheme.light, .dark] {
        try check(WorkspaceControlNavigationButton(titleKey: "control.layoutPanel", symbol: "sidebar.right",
                                                   isSelected: false, showsArrow: true, action: {})
            .environment(\.colorScheme, scheme), width: 160, height: 34, name: "panel-shortcut-\(scheme)")
    }
    try check(HStack(spacing: 24) {
        AppLogoView(size: 64)
        AppLogoView(size: 64, monochrome: true)
        GitHubMark().frame(width: 48, height: 48)
        GitHubLink(showsAddress: true)
        QuitApplicationButton()
    }.padding(24), width: 620, height: 120, name: "branding")
}
