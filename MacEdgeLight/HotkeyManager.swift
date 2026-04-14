import Cocoa
import Carbon.HIToolbox

/// Rolling-window tap counter. `register(at:)` records a timestamp; returns
/// true (and resets) when `threshold` taps land within `window` seconds.
/// Pure logic — no NSEvent or clock dependency — so it's unit-testable.
struct PanicTapDetector {
    let threshold: Int
    let window: TimeInterval
    private(set) var taps: [TimeInterval] = []

    mutating func register(at time: TimeInterval) -> Bool {
        taps.append(time)
        taps.removeAll { time - $0 > window }
        if taps.count >= threshold {
            taps.removeAll()
            return true
        }
        return false
    }
}

class HotkeyManager {
    typealias HotkeyAction = () -> Void

    private var toggleAction: HotkeyAction?
    private var brightnessUpAction: HotkeyAction?
    private var brightnessDownAction: HotkeyAction?
    private var boostAction: HotkeyAction?
    private var panicQuitAction: HotkeyAction?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // 5 unmodified "Q" key taps within 2s quits the app
    private var panicDetector = PanicTapDetector(threshold: 5, window: 2.0)

    func register(
        toggle: @escaping HotkeyAction,
        brightnessUp: @escaping HotkeyAction,
        brightnessDown: @escaping HotkeyAction,
        boost: @escaping HotkeyAction,
        panicQuit: @escaping HotkeyAction
    ) {
        self.toggleAction = toggle
        self.brightnessUpAction = brightnessUp
        self.brightnessDownAction = brightnessDown
        self.boostAction = boost
        self.panicQuitAction = panicQuit

        // Global monitor catches events when app is NOT focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor catches events when app IS focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume the event
            }
            return event
        }

    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Panic quit: 5 unmodified "Q" taps in 2s. Ignore auto-repeat.
        if event.keyCode == UInt16(kVK_ANSI_Q) && flags.isEmpty && !event.isARepeat {
            if panicDetector.register(at: Date().timeIntervalSinceReferenceDate) {
                panicQuitAction?()
            }
        }

        let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]
        guard flags.contains(requiredFlags) else { return false }

        switch event.keyCode {
        case UInt16(kVK_ANSI_L): // Cmd+Shift+L
            toggleAction?()
            return true
        case UInt16(kVK_ANSI_B): // Cmd+Shift+B
            boostAction?()
            return true
        case UInt16(kVK_UpArrow): // Cmd+Shift+Up
            brightnessUpAction?()
            return true
        case UInt16(kVK_DownArrow): // Cmd+Shift+Down
            brightnessDownAction?()
            return true
        default:
            return false
        }
    }

    func unregister() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        unregister()
    }
}
