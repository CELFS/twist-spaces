import AppKit
import SwiftUI
import Testing
@testable import TwistSpaces

@Test func panelLeavesSpaceAroundEitherScreenEdge() {
    let screen = CGRect(x: -1920, y: 40, width: 1920, height: 1000)
    for left in [true, false] {
        let frame = PanelAppearance.frame(in: screen, width: 340, leftSide: left)
        #expect(frame.width == 340)
        #expect(frame.minY == screen.minY + 12)
        #expect(frame.maxY == screen.maxY - 12)
        #expect(left ? frame.minX == screen.minX + 12 : frame.maxX == screen.maxX - 12)
    }
}

@Test func panelFitsSmallDisplaysWithoutLosingItsMargin() {
    let screen = CGRect(x: 80, y: -500, width: 320, height: 400)
    let frame = PanelAppearance.frame(in: screen, width: 700, leftSide: false)
    #expect(frame.width == 296)
    #expect(frame.minX == 92)
    #expect(frame.maxX == 388)
    #expect(screen.contains(frame))
}

@Test @MainActor func restoredDefaultMigratesOnlyOnceAndKeepsOtherSettings() throws {
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(340, forKey: "panel.displayWidth")
    defaults.set(true, forKey: "panel.edgeEnabled")
    let settings = PanelSettings(defaults: defaults)
    #expect(settings.width == 460)
    #expect(settings.edgeEnabled)
    settings.width = 340
    #expect(PanelSettings(defaults: defaults).width == 340)
}

@Test @MainActor func customWidthIsPreservedAndFreshDefaultsAre460Points() throws {
    let suite = "local.twist-spaces.tests.\(ProcessInfo.processInfo.globallyUniqueString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(PanelSettings(defaults: defaults).width == 460)
    defaults.removeObject(forKey: "panel.displayWidth")
    defaults.set(520, forKey: "panel.width")
    #expect(PanelSettings(defaults: defaults).width == 520)
}

@Test @MainActor func sharedPickerDoesNotFillItsParentWidth() {
    let picker = AppPicker(titleKey: "panel.side", selection: .constant(false), width: .compact) {
        Text("Left").tag(true)
        Text("Right").tag(false)
    }
    let host = NSHostingView(rootView: picker)
    #expect(host.fittingSize.width == AppFormLayout.contentInset + AppPickerWidth.compact.rawValue)
}

@Test @MainActor func nativeGlassKeepsFullBackdropOpacityAndRoundedMask() {
    let view = PanelGlassView(frame: CGRect(x: 0, y: 0, width: 460, height: 700))
    #expect(view.alphaValue == 1)
    #expect(view.material == .hudWindow)
    #expect(view.blendingMode == .behindWindow)
    #expect(view.state == .active)
    #expect(view.maskImage != nil)
    #expect(PanelAppearance.defaultWidth == 460)
}
