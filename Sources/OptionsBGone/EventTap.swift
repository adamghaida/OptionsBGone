import AppKit
import CoreGraphics

/// Wraps a CGEventTap that watches mouse-button events.
///
/// For each button *down* the tap asks its owner what to do:
///  - return `true`  -> the event is swallowed (default OS behaviour suppressed)
///  - return `false` -> the event passes through untouched
final class EventTap {
    /// Called on button down/up. `down` is true for press, false for release.
    /// Return true to swallow the event. Release events are always passed through
    /// (return value ignored) but reported so callers can track state.
    var onButton: (_ button: Int, _ down: Bool) -> Bool = { _, _ in false }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Returns false if the tap could not be created (usually: no Accessibility permission).
    @discardableResult
    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables a tap that is slow or gets interrupted; re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        let isDown = (type == .otherMouseDown)
        let swallow = onButton(button, isDown)

        if isDown && swallow {
            return nil // suppress the default action for this button
        }
        return Unmanaged.passUnretained(event)
    }

    var isRunning: Bool { tap != nil }
}
