import Cocoa

class EdgeLightManager {
    let settings = AppSettings.shared
    private(set) var monitorManager: MonitorManager
    private var hotkeyManager = HotkeyManager()
    private var controlPanel: ControlPanelWindow?
    private var statusBar: StatusBarController?
    private var magnifierWindow: MagnifierWindow?
    private var edrInfoWindow: EDRInfoWindow?
    private var screenChangeObserver: Any?
    private var willSleepObserver: Any?
    private var didWakeObserver: Any?

    private let brightnessStep = 0.15
    private let brightnessStepFine = 0.025
    private let minBrightness = 0.2
    private let maxBrightness = 2.0
    private let colorTempStep = 0.1
    private let colorTempStepFine = 0.015
    private let borderWidthStep = 10.0
    private let borderWidthStepFine = 2.0
    private let minBorderWidth = 10.0
    private let maxBorderWidth = 150.0

    init() {
        monitorManager = MonitorManager(settings: settings)
    }

    func start() {
        // Create overlay windows
        monitorManager.createOverlays()

        // Wipe any leaked gamma LUT from a prior crashed run or dirty sleep
        // cycle before anything else touches display transfer tables.
        DisplayBrightnessManager.resetGammaToProfile()

        // Restore EDR brightness boost state before UI is created
        if settings.edrBoosted && DisplayBrightnessManager.shared.isAvailable {
            DisplayBrightnessManager.shared.toggle()
        }

        // Create control panel
        controlPanel = ControlPanelWindow(manager: self)
        if settings.showControlPanel {
            controlPanel?.orderFrontRegardless()
        }
        positionControlPanel()
        controlPanel?.updateToggleStates()

        // Set up menu bar
        statusBar = StatusBarController(manager: self)
        statusBar?.updateControlsMenuTitle(visible: settings.showControlPanel)

        // Sync launch-at-login state with the system
        LoginItemManager.shared.syncWithSystemState()

        // Register hotkeys
        hotkeyManager.register(
            toggle: { [weak self] in self?.toggleLight() },
            brightnessUp: { [weak self] in self?.increaseBrightness() },
            brightnessDown: { [weak self] in self?.decreaseBrightness() },
            panicQuit: { NSApp.terminate(nil) }
        )

        // Restore magnifier state
        if settings.magnifierEnabled {
            showMagnifier()
        }

        // Show EDR info window when running under debugger
        if EDRInfoWindow.isDebuggerAttached() {
            let info = EDRInfoWindow()
            info.orderFrontRegardless()
            info.startUpdating()
            edrInfoWindow = info
        }

        // Listen for screen configuration changes (monitor plug/unplug)
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard !DisplayBrightnessManager.shared.isChanging else { return }
            self?.monitorManager.refreshForScreenChanges()
            self?.positionControlPanel()
        }

        // Tear the XDR boost down before sleep and rebuild it after wake.
        // Restoring across sleep in place is unreliable — headroom vanishes
        // while our boosted gamma LUT stays live, and macOS can restore a
        // dirty LUT cached from before sleep. We deactivate without touching
        // `settings.edrBoosted` so it survives sleep and drives re-activation
        // on wake after the gamma has been wiped clean.
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        willSleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { _ in
            if DisplayBrightnessManager.shared.isBoosted {
                DisplayBrightnessManager.shared.toggle()
            }
        }
        didWakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            DisplayBrightnessManager.resetGammaToProfile()
            guard let self,
                  self.settings.edrBoosted,
                  DisplayBrightnessManager.shared.isAvailable else { return }
            // Let macOS settle headroom before we re-engage the boost.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self,
                      self.settings.edrBoosted,
                      !DisplayBrightnessManager.shared.isBoosted else { return }
                DisplayBrightnessManager.shared.toggle()
                self.controlPanel?.updateToggleStates()
                self.statusBar?.updateEDRMenuState()
            }
        }
    }

    func stop() {
        hotkeyManager.unregister()
        monitorManager.removeAllOverlays()
        hideMagnifier()
        edrInfoWindow?.close()
        edrInfoWindow = nil
        controlPanel?.close()
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        if let observer = willSleepObserver {
            workspaceCenter.removeObserver(observer)
            willSleepObserver = nil
        }
        if let observer = didWakeObserver {
            workspaceCenter.removeObserver(observer)
            didWakeObserver = nil
        }
    }

    // MARK: - Light Controls

    func toggleLight() {
        settings.isLightOn.toggle()
        monitorManager.applySettingsToAll()
        controlPanel?.updateToggleStates()
    }

    func increaseBrightness() {
        settings.brightness = min(maxBrightness, settings.brightness + brightnessStep)
        monitorManager.applySettingsToAll()
    }

    func decreaseBrightness() {
        settings.brightness = max(minBrightness, settings.brightness - brightnessStep)
        monitorManager.applySettingsToAll()
    }

    func increaseBrightnessFine() {
        settings.brightness = min(maxBrightness, settings.brightness + brightnessStepFine)
        monitorManager.applySettingsToAll()
    }

    func decreaseBrightnessFine() {
        settings.brightness = max(minBrightness, settings.brightness - brightnessStepFine)
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

    func increaseColorTemperatureFine() {
        settings.colorTemperature = min(1.0, settings.colorTemperature + colorTempStepFine)
        monitorManager.applySettingsToAll()
    }

    func decreaseColorTemperatureFine() {
        settings.colorTemperature = max(0.0, settings.colorTemperature - colorTempStepFine)
        monitorManager.applySettingsToAll()
    }

    func increaseBorderWidth() {
        settings.borderWidth = min(maxBorderWidth, settings.borderWidth + borderWidthStep)
        monitorManager.applySettingsToAll()
    }

    func decreaseBorderWidth() {
        settings.borderWidth = max(minBorderWidth, settings.borderWidth - borderWidthStep)
        monitorManager.applySettingsToAll()
    }

    func increaseBorderWidthFine() {
        settings.borderWidth = min(maxBorderWidth, settings.borderWidth + borderWidthStepFine)
        monitorManager.applySettingsToAll()
    }

    func decreaseBorderWidthFine() {
        settings.borderWidth = max(minBorderWidth, settings.borderWidth - borderWidthStepFine)
        monitorManager.applySettingsToAll()
    }

    /// Resets only the ring light visual settings (brightness, color, border, menu bar mode, cursor reveal).
    /// Leaves EDR boost, magnifier, desktop icons, and capture visibility unchanged.
    func resetRingLight() {
        settings.brightness = 1.0
        settings.colorTemperature = 0.5
        settings.isLightOn = true
        settings.menuBarMode = 2
        settings.cursorRevealEnabled = false
        settings.borderWidth = 60.0
        monitorManager.applySettingsToAll()
        controlPanel?.updateToggleStates()
    }

    func resetToDefaults() {
        let wasDesktopHidden = settings.desktopIconsHidden
        if DisplayBrightnessManager.shared.isBoosted {
            DisplayBrightnessManager.shared.toggle()
        }
        settings.resetToDefaults()
        // Restore desktop icons if they were hidden
        if wasDesktopHidden {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            task.arguments = ["write", "com.apple.finder", "CreateDesktop", "-bool", "true"]
            try? task.run()
            task.waitUntilExit()
            let killall = Process()
            killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killall.arguments = ["Finder"]
            try? killall.run()
        }
        monitorManager.applySettingsToAll()
        controlPanel?.updateToggleStates()
        statusBar?.updateDesktopIconsMenuTitle()
    }

    func cycleMenuBarMode() {
        settings.menuBarMode = (settings.menuBarMode + 1) % 3
        monitorManager.applySettingsToAll()
        controlPanel?.updateToggleStates()
    }

    func toggleCursorReveal() {
        settings.cursorRevealEnabled.toggle()
        monitorManager.applySettingsToAll()
        controlPanel?.updateToggleStates()
    }

    func toggleScreenCapture() {
        settings.visibleInCapture.toggle()
        monitorManager.applySettingsToAll()
        controlPanel?.updateToggleStates()
    }

    func toggleDesktopIcons() {
        settings.desktopIconsHidden.toggle()
        let hidden = settings.desktopIconsHidden
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["write", "com.apple.finder", "CreateDesktop", "-bool", hidden ? "false" : "true"]
        try? task.run()
        task.waitUntilExit()
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Finder"]
        try? killall.run()
        controlPanel?.updateToggleStates()
        statusBar?.updateDesktopIconsMenuTitle()
    }

    // MARK: - Display Brightness Boost

    func toggleDisplayBrightness() {
        DisplayBrightnessManager.shared.toggle()
        settings.edrBoosted = DisplayBrightnessManager.shared.isBoosted
        controlPanel?.updateToggleStates()
        statusBar?.updateEDRMenuState()
    }

    // MARK: - Magnifier

    func toggleMagnifier() {
        settings.magnifierEnabled.toggle()
        if settings.magnifierEnabled {
            showMagnifier()
        } else {
            hideMagnifier()
        }
        controlPanel?.updateToggleStates()
    }

    private func showMagnifier() {
        if magnifierWindow == nil {
            magnifierWindow = MagnifierWindow()
        }
        magnifierWindow?.orderFrontRegardless()
        magnifierWindow?.startTracking()
    }

    private func hideMagnifier() {
        magnifierWindow?.stopTracking()
        magnifierWindow?.orderOut(nil)
    }

    // MARK: - Monitor Controls

    func moveToNextMonitor() {
        monitorManager.moveToNextMonitor()
        positionControlPanel()
    }

    func toggleAllMonitors() {
        monitorManager.toggleAllMonitors()
        positionControlPanel()
        controlPanel?.updateToggleStates()
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
