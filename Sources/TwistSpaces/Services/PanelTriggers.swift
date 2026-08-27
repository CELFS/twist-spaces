import AppKit
import Carbon

@MainActor
final class PanelTriggers {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var timer: Timer?
    private var edgeEnteredAt: Date?
    private var edgeFired = false
    var show: (() -> Void)?
    var toggle: (() -> Void)?
    var shortcutFailed: (() -> Void)?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<PanelTriggers>.fromOpaque(context).takeUnretainedValue().toggle?()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    func configure(_ settings: PanelSettings) {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if settings.shortcutEnabled {
            // Register one explicit shortcut instead of monitoring arbitrary keyboard input.
            let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey),
                EventHotKeyID(signature: 0x54575350, id: 1), GetApplicationEventTarget(), 0, &hotKey)
            if status != noErr { shortcutFailed?() }
        }
        timer?.invalidate()
        timer = nil
        edgeEnteredAt = nil
        edgeFired = false
        guard settings.edgeEnabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, weak settings] _ in
            MainActor.assumeIsolated {
                guard let self, let settings else { return }
                let point = NSEvent.mouseLocation
                guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }),
                      point.y >= screen.visibleFrame.minY, point.y <= screen.visibleFrame.maxY,
                      settings.leftSide ? point.x <= screen.frame.minX + 2 : point.x >= screen.frame.maxX - 2 else {
                    self.edgeEnteredAt = nil
                    self.edgeFired = false
                    return
                }
                if self.edgeEnteredAt == nil { self.edgeEnteredAt = Date() }
                if !self.edgeFired, let entered = self.edgeEnteredAt, Date().timeIntervalSince(entered) >= settings.edgeDelay {
                    self.edgeFired = true
                    self.show?()
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}
