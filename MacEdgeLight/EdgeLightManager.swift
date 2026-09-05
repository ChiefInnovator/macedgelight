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
    private var screenLockObserver: Any?
    private var screenUnlockObserver: Any?
    private var boostRecovery = BoostRecoveryState()
    private var boostRecoveryTimer: Timer?
    private var boostWorkspaceObservers: [NSObjectProtocol] = []

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
        precondition(Thread.isMainThread)
        guard !boostRecovery.isRunning else { return }
        boostRecovery.isRunning = true
        boostRecovery.isSessionActive = true
        updateBoostSessionState()

        // Create overlay windows
        monitorManager.createOverlays()

        // Wipe any leaked gamma LUT from a prior crashed run or dirty sleep
        // cycle before anything else touches display transfer tables.
        DisplayBrightnessManager.resetGammaToProfile()

        // The persisted preference survives temporary system suspension.
        reconcileBoost()

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
            boost: { [weak self] in self?.toggleDisplayBrightness() },
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
            self?.reconcileBoost()
            DisplayBrightnessManager.shared.refreshDisplayConfiguration()
            guard !DisplayBrightnessManager.shared.isChanging else { return }
            self?.monitorManager.refreshForScreenChanges()
            self?.positionControlPanel()
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        willSleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleBoostEvent(.systemSleep)
        }
        didWakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleBoostEvent(.systemWake)
        }
        boostWorkspaceObservers = [
            workspaceCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                                        object: nil, queue: .main) { [weak self] _ in
                self?.handleBoostEvent(.displaySleep)
            },
            workspaceCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                                        object: nil, queue: .main) { [weak self] _ in
                self?.handleBoostEvent(.displayWake)
            },
            workspaceCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification,
                                        object: nil, queue: .main) { [weak self] _ in
                self?.handleBoostEvent(.sessionInactive)
            },
            workspaceCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification,
                                        object: nil, queue: .main) { [weak self] _ in
                self?.handleBoostEvent(.sessionActive)
            }
        ]

        let distributedCenter = DistributedNotificationCenter.default()
        screenLockObserver = distributedCenter.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleBoostEvent(.lock)
        }
        screenUnlockObserver = distributedCenter.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleBoostEvent(.unlock)
        }

        // Recovery must outlive a slow login handoff or temporarily missing
        // display. It is independent of Metal frame delivery and never gives up.
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.reconcileBoost()
        }
        RunLoop.main.add(timer, forMode: .common)
        boostRecoveryTimer = timer
    }

    func stop() {
        precondition(Thread.isMainThread)
        guard boostRecovery.isRunning else { return }
        boostRecovery.isRunning = false
        boostRecoveryTimer?.invalidate()
        boostRecoveryTimer = nil
        DisplayBrightnessManager.shared.restore()
        hotkeyManager.unregister()
        monitorManager.removeAllOverlays()
        hideMagnifier()
        edrInfoWindow?.close()
        edrInfoWindow = nil
        controlPanel?.close()
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            screenChangeObserver = nil
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
        for observer in boostWorkspaceObservers { workspaceCenter.removeObserver(observer) }
        boostWorkspaceObservers.removeAll()
        let distributedCenter = DistributedNotificationCenter.default()
        if let observer = screenLockObserver {
            distributedCenter.removeObserver(observer)
            screenLockObserver = nil
        }
        if let observer = screenUnlockObserver {
            distributedCenter.removeObserver(observer)
            screenUnlockObserver = nil
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
        settings.resetToDefaults()
        DisplayBrightnessManager.shared.setEnabled(false)
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
        // Toggle intent, not temporary hardware state. Off during recovery must
        // cancel the request, rather than accidentally turning boost back on.
        settings.edrBoosted.toggle()
        reconcileBoost()
    }

    private func handleBoostEvent(_ event: BoostRecoveryState.Event) {
        precondition(Thread.isMainThread)
        guard boostRecovery.isRunning else { return }
        boostRecovery.handle(event, now: ProcessInfo.processInfo.systemUptime)
        let wasBoosted = DisplayBrightnessManager.shared.isBoosted
        DisplayBrightnessManager.shared.setEnabled(false)
        // Deactivation already restores ColorSync. Only reset it separately
        // when resuming a desired boost that was already suspended.
        if event.resumeDelay != nil, settings.edrBoosted, !wasBoosted {
            DisplayBrightnessManager.resetGammaToProfile()
        }
        refreshBoostUI()
    }

    private func reconcileBoost() {
        guard !DisplayBrightnessManager.shared.isChanging else { return }
        updateBoostSessionState()
        let enabled = boostRecovery.shouldEnable(
            desired: settings.edrBoosted,
            available: DisplayBrightnessManager.shared.isAvailable,
            now: ProcessInfo.processInfo.systemUptime
        )
        DisplayBrightnessManager.shared.setEnabled(enabled)
        refreshBoostUI()
    }

    private func refreshBoostUI() {
        controlPanel?.updateToggleStates()
        statusBar?.updateEDRMenuState()
    }

    private func updateBoostSessionState() {
        guard let sessionInfo = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            // No accessible user session: fail closed, retry on the next tick.
            boostRecovery.sessionIsUsable = false
            return
        }
        // Notifications suspend immediately; a lagging dictionary must not
        // override them. Conversely, an unlock notification is not enough if
        // the live session still reports locked or off-console.
        let locked = sessionInfo["CGSSessionScreenIsLocked"] as? Bool ?? boostRecovery.isScreenLocked
        boostRecovery.sessionIsUsable = sessionInfo[kCGSessionOnConsoleKey as String] as? Bool == true
            && sessionInfo[kCGSessionLoginDoneKey as String] as? Bool == true
            && !locked
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

/// Recovery eligibility is separate from the persisted user preference and the
/// running renderer. No retry budget: a late display/session is still eligible.
struct BoostRecoveryState {
    enum Event: CaseIterable {
        case systemSleep, systemWake, displaySleep, displayWake
        case lock, unlock, sessionInactive, sessionActive

        var resumeDelay: TimeInterval? {
            switch self {
            case .systemWake, .displayWake: return 2.0
            case .unlock, .sessionActive: return 0.75
            default: return nil
            }
        }
    }

    var isRunning = false
    var isSleeping = false
    var isDisplaySleeping = false
    var isScreenLocked = false
    var isSessionActive = false
    var sessionIsUsable = false
    private(set) var resumeNotBefore: TimeInterval = 0

    mutating func handle(_ event: Event, now: TimeInterval) {
        switch event {
        case .systemSleep: isSleeping = true
        case .systemWake: isSleeping = false
        case .displaySleep: isDisplaySleeping = true
        case .displayWake: isDisplaySleeping = false
        case .lock: isScreenLocked = true
        case .unlock: isScreenLocked = false
        case .sessionInactive: isSessionActive = false
        case .sessionActive: isSessionActive = true
        }
        if let delay = event.resumeDelay {
            settle(after: delay, now: now)
        }
    }

    mutating func settle(after delay: TimeInterval, now: TimeInterval) {
        // An unlock arriving after wake must not shorten the wake settle delay.
        resumeNotBefore = max(resumeNotBefore, now + delay)
    }

    func shouldEnable(desired: Bool, available: Bool, now: TimeInterval) -> Bool {
        isRunning && desired && available && isSessionActive && sessionIsUsable
            && !isSleeping && !isDisplaySleeping && !isScreenLocked
            && now >= resumeNotBefore
    }
}
