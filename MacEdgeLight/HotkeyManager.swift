import Cocoa
import Carbon.HIToolbox

class HotkeyManager {
    typealias HotkeyAction = () -> Void

    private var toggleAction: HotkeyAction?
    private var brightnessUpAction: HotkeyAction?
    private var brightnessDownAction: HotkeyAction?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func register(
        toggle: @escaping HotkeyAction,
        brightnessUp: @escaping HotkeyAction,
        brightnessDown: @escaping HotkeyAction
    ) {
        self.toggleAction = toggle
        self.brightnessUpAction = brightnessUp
        self.brightnessDownAction = brightnessDown

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
        let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]

        guard flags.contains(requiredFlags) else { return false }

        switch event.keyCode {
        case UInt16(kVK_ANSI_L): // Cmd+Shift+L
            toggleAction?()
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
