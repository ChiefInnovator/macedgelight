import Cocoa

class EdgeLightManager {
    let settings = AppSettings.shared
    private(set) var monitorManager: MonitorManager
    private var hotkeyManager = HotkeyManager()
    private var controlPanel: ControlPanelWindow?
    private var statusBar: StatusBarController?
    private var screenChangeObserver: Any?

    private let brightnessStep = 0.15
    private let minBrightness = 0.2
    private let maxBrightness = 2.0
    private let colorTempStep = 0.1

    init() {
        monitorManager = MonitorManager(settings: settings)
    }

    func start() {
        // Create overlay windows
        monitorManager.createOverlays()

        // Create control panel
        controlPanel = ControlPanelWindow(manager: self)
        if settings.showControlPanel {
            controlPanel?.orderFrontRegardless()
        }
        positionControlPanel()

        // Set up menu bar
        statusBar = StatusBarController(manager: self)
        statusBar?.updateControlsMenuTitle(visible: settings.showControlPanel)

        // Sync launch-at-login state with the system
        LoginItemManager.shared.syncWithSystemState()

        // Register hotkeys
        hotkeyManager.register(
            toggle: { [weak self] in self?.toggleLight() },
            brightnessUp: { [weak self] in self?.increaseBrightness() },
            brightnessDown: { [weak self] in self?.decreaseBrightness() }
        )

        // Listen for screen configuration changes (monitor plug/unplug)
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.monitorManager.refreshForScreenChanges()
            self?.positionControlPanel()
        }
    }

    func stop() {
        hotkeyManager.unregister()
        monitorManager.removeAllOverlays()
        controlPanel?.close()
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Light Controls

    func toggleLight() {
        settings.isLightOn.toggle()
        monitorManager.applySettingsToAll()
    }

    func increaseBrightness() {
        settings.brightness = min(maxBrightness, settings.brightness + brightnessStep)
        monitorManager.applySettingsToAll()
    }

    func decreaseBrightness() {
        settings.brightness = max(minBrightness, settings.brightness - brightnessStep)
        monitorManager.applySettingsToAll()
    }

    func increaseColorTemperature() {
        settings.colorTemperature = min(1.0, settings.colorTemperature + colorTempStep)
        monitorManager.applySettingsToAll()
    }

    func decreaseColorTemperature() {
        settings.colorTemperature = max(0.0, settings.colorTemperature - colorTempStep)
        monitorManager.applySettingsToAll()
    }

    func toggleExtendOverMenuBar() {
        settings.extendOverMenuBar.toggle()
        monitorManager.applySettingsToAll()
    }

    func toggleCursorReveal() {
        settings.cursorRevealEnabled.toggle()
        monitorManager.applySettingsToAll()
    }

    // MARK: - Monitor Controls

    func moveToNextMonitor() {
        monitorManager.moveToNextMonitor()
        positionControlPanel()
    }

    func toggleAllMonitors() {
        monitorManager.toggleAllMonitors()
        positionControlPanel()
    }

    // MARK: - Control Panel

    func toggleControlPanel() {
        settings.showControlPanel.toggle()
        if settings.showControlPanel {
            controlPanel?.orderFrontRegardless()
        } else {
            controlPanel?.orderOut(nil)
        }
        statusBar?.updateControlsMenuTitle(visible: settings.showControlPanel)
    }

    private func positionControlPanel() {
        guard let panel = controlPanel else { return }
        let screens = NSScreen.screens
        let index = min(settings.currentMonitorIndex, screens.count - 1)
        let validIndex = max(0, index)
        if validIndex < screens.count {
            panel.positionOnScreen(screens[validIndex])
        }
    }
}
