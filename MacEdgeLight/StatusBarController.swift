import Cocoa
import Combine

class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem
    private weak var edgeLightManager: EdgeLightManager?
    private var toggleControlsItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?
    private var menuBarModeItem: NSMenuItem?
    private var edrToggleItem: NSMenuItem?
    private var desktopIconsItem: NSMenuItem?
    private var settingsObservation: AnyCancellable?
    var menu: NSMenu? { statusItem.menu }

    init(manager: EdgeLightManager) {
        self.edgeLightManager = manager

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "Mac Edge Light")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        setupMenu()
        refreshMenuState()
        // @Published sends before storage changes; refresh after the setter finishes.
        settingsObservation = AppSettings.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.refreshMenuState() }
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(NSMenuItem(title: "Keyboard Shortcuts", action: #selector(showHelp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let lightItem = NSMenuItem(title: "", action: #selector(toggleLight), keyEquivalent: "")
        menu.addItem(lightItem)
        menu.addItem(NSMenuItem(title: "Brightness Up (Cmd+Shift+Up)", action: #selector(brightnessUp), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Brightness Down (Cmd+Shift+Down)", action: #selector(brightnessDown), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Warmer Light", action: #selector(colorWarmer), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Cooler Light", action: #selector(colorCooler), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Thicker Border", action: #selector(borderThicker), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Thinner Border", action: #selector(borderThinner), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Switch Monitor", action: #selector(switchMonitor), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Toggle All Monitors", action: #selector(allMonitors), keyEquivalent: ""))
        let mbItem = NSMenuItem(title: menuBarModeTitle(), action: #selector(toggleMenuBarOverlay), keyEquivalent: "")
        menuBarModeItem = mbItem
        menu.addItem(mbItem)
        menu.addItem(NSMenuItem(title: "Cursor Reveal", action: #selector(toggleCursorReveal), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Magnifier", action: #selector(toggleMagnifier), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show in Screen Capture", action: #selector(toggleScreenCapture), keyEquivalent: ""))
        let desktopItem = NSMenuItem(title: desktopIconsTitle(), action: #selector(toggleDesktopIcons), keyEquivalent: "")
        desktopIconsItem = desktopItem
        menu.addItem(desktopItem)
        let supported = DisplayBrightnessManager.shared.isAvailable
        let edrTitle = "Display Brightness Boost"
        let edrItem = NSMenuItem(title: edrTitle, action: #selector(toggleDisplayBrightness), keyEquivalent: "")
        edrItem.target = self
        edrItem.state = AppSettings.shared.edrBoosted ? .on : .off
        edrItem.isEnabled = supported || AppSettings.shared.edrBoosted
        edrToggleItem = edrItem
        menu.addItem(edrItem)
        menu.addItem(NSMenuItem.separator())

        let toggleControls = NSMenuItem(title: "Hide Controls", action: #selector(toggleControls), keyEquivalent: "")
        toggleControlsItem = toggleControls
        menu.addItem(toggleControls)

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = AppSettings.shared.launchAtLogin ? .on : .off
        launchAtLoginItem = launchItem
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem(title: "Reset to Defaults", action: #selector(resetDefaults), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Mac Edge Light", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit Mac Edge Light", action: #selector(quit), keyEquivalent: "q"))

        // Set targets
        for item in menu.items {
            item.target = self
        }

        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        LoginItemManager.shared.syncWithSystemState()
        refreshMenuState()
    }

    func refreshMenuState() {
        let settings = AppSettings.shared
        let toggles: [(Selector, String, Bool)] = [
            (#selector(toggleLight), "Toggle Light", settings.isLightOn),
            (#selector(allMonitors), "All Monitors", settings.showOnAllMonitors),
            (#selector(toggleCursorReveal), "Cursor Reveal", settings.cursorRevealEnabled),
            (#selector(toggleMagnifier), "Magnifier", settings.magnifierEnabled),
            (#selector(toggleScreenCapture), "Show in Screen Capture", settings.visibleInCapture),
            (#selector(toggleDesktopIcons), "Hide Desktop Icons", settings.desktopIconsHidden),
            (#selector(toggleControls), "Show Controls", settings.showControlPanel),
            (#selector(toggleLaunchAtLogin), "Launch at Login", settings.launchAtLogin)
        ]
        for (action, label, enabled) in toggles {
            guard let item = menu?.items.first(where: { $0.action == action }) else { continue }
            item.title = "\(label) — \(enabled ? "ON" : "OFF")"
            if action == #selector(toggleLight) { item.title += " (Cmd+Shift+L)" }
            item.state = enabled ? .on : .off
        }
        let lightActions: [Selector] = [#selector(brightnessUp), #selector(brightnessDown),
            #selector(colorWarmer), #selector(colorCooler), #selector(borderThicker),
            #selector(borderThinner), #selector(switchMonitor), #selector(allMonitors),
            #selector(toggleMenuBarOverlay), #selector(toggleCursorReveal), #selector(toggleScreenCapture)]
        for item in menu?.items ?? [] where item.action.map(lightActions.contains) == true {
            item.isEnabled = settings.isLightOn
        }
        menuBarModeItem?.title = menuBarModeTitle()
        menuBarModeItem?.state = settings.menuBarMode == 0 ? .off : .on
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: settings.isLightOn ? "lightbulb.fill" : "lightbulb",
                                   accessibilityDescription: "MacEdgeLight ring light")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            button.toolTip = "MacEdgeLight — Ring Light \(settings.isLightOn ? "ON" : "OFF")"
            button.setAccessibilityValue(settings.isLightOn ? "ON" : "OFF")
        }
        updateEDRMenuState()
    }

    func updateControlsMenuTitle(visible: Bool) {
        refreshMenuState()
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Mac Edge Light - Keyboard Shortcuts"
        alert.informativeText = """
        Toggle Light:  Cmd + Shift + L
        Brightness Up:  Cmd + Shift + Up
        Brightness Down:  Cmd + Shift + Down

        Features:
        - Click-through overlay - won't interfere with your work
        - Global hotkeys work from any application
        - Menu bar icon for full controls
        - Floating control toolbar
        - Color temperature controls (warmer/cooler)
        - Switch between monitors or show on all monitors
        - Toggle screen capture visibility (hidden by default)

        Based on Windows Edge Light by Scott Hanselman
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleLight() {
        edgeLightManager?.toggleLight()
    }

    @objc private func brightnessUp() {
        edgeLightManager?.increaseBrightness()
    }

    @objc private func brightnessDown() {
        edgeLightManager?.decreaseBrightness()
    }

    @objc private func colorWarmer() {
        edgeLightManager?.increaseColorTemperature()
    }

    @objc private func colorCooler() {
        edgeLightManager?.decreaseColorTemperature()
    }

    @objc private func borderThicker() {
        edgeLightManager?.increaseBorderWidth()
    }

    @objc private func borderThinner() {
        edgeLightManager?.decreaseBorderWidth()
    }

    @objc private func switchMonitor() {
        edgeLightManager?.moveToNextMonitor()
    }

    @objc private func allMonitors() {
        edgeLightManager?.toggleAllMonitors()
    }

    @objc private func toggleMenuBarOverlay() {
        edgeLightManager?.cycleMenuBarMode()
        menuBarModeItem?.title = menuBarModeTitle()
    }

    private func menuBarModeTitle() -> String {
        switch AppSettings.shared.menuBarMode {
        case 1: return "Menu Bar: Extend"
        case 2: return "Menu Bar: Auto"
        default: return "Menu Bar: Below"
        }
    }

    @objc private func toggleCursorReveal() {
        edgeLightManager?.toggleCursorReveal()
    }

    @objc private func toggleMagnifier() {
        edgeLightManager?.toggleMagnifier()
    }

    @objc private func toggleScreenCapture() {
        edgeLightManager?.toggleScreenCapture()
    }

    @objc private func toggleDesktopIcons() {
        edgeLightManager?.toggleDesktopIcons()
    }

    private func desktopIconsTitle() -> String {
        AppSettings.shared.desktopIconsHidden ? "Show Desktop Icons" : "Hide Desktop Icons"
    }

    @objc private func toggleDisplayBrightness() {
        edgeLightManager?.toggleDisplayBrightness()
    }

    func updateEDRMenuState() {
        let desired = AppSettings.shared.edrBoosted
        let supported = DisplayBrightnessManager.shared.isAvailable
        edrToggleItem?.state = desired ? .on : .off
        edrToggleItem?.isEnabled = supported || desired
        edrToggleItem?.title = supported || desired
            ? "Display Brightness Boost — \(desired ? "ON" : "OFF")" : "Display Brightness Boost — OFF (Not Supported)"
        let recoveryMessage = edgeLightManager?.boostRecoveryMessage
        if recoveryMessage != nil { edrToggleItem?.title = "Display Brightness Boost — WAITING" }
        edrToggleItem?.toolTip = recoveryMessage
    }

    func updateDesktopIconsMenuTitle() {
        refreshMenuState()
    }

    @objc private func toggleControls() {
        edgeLightManager?.toggleControlPanel()
    }

    @objc private func toggleLaunchAtLogin() {
        let settings = AppSettings.shared
        let newValue = !settings.launchAtLogin
        settings.launchAtLogin = newValue
        LoginItemManager.shared.setLaunchAtLogin(enabled: newValue)
        refreshMenuState()
    }

    @objc private func resetDefaults() {
        edgeLightManager?.resetToDefaults()
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        let alert = NSAlert()
        alert.messageText = "Mac Edge Light"
        alert.informativeText = """
        Version \(version) (Build \(build))

        An ambient edge light for macOS that wraps your screen in a glowing frame.

        Inspired by Windows Edge Light by Scott Hanselman.

        \u{00A9} 2026 Richard Crane. All rights reserved.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        // Bring our app to front so the alert is visible
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
