import Cocoa

class StatusBarController {
    private var statusItem: NSStatusItem
    private weak var edgeLightManager: EdgeLightManager?
    private var toggleControlsItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?
    private var menuBarModeItem: NSMenuItem?

    init(manager: EdgeLightManager) {
        self.edgeLightManager = manager

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "Mac Edge Light")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Keyboard Shortcuts", action: #selector(showHelp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Toggle Light (Cmd+Shift+L)", action: #selector(toggleLight), keyEquivalent: ""))
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
        menu.addItem(NSMenuItem(title: "Show in Screen Capture", action: #selector(toggleScreenCapture), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Hide Desktop Icons", action: #selector(toggleDesktopIcons), keyEquivalent: ""))
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

        statusItem.menu = menu
    }

    func updateControlsMenuTitle(visible: Bool) {
        toggleControlsItem?.title = visible ? "Hide Controls" : "Show Controls"
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

    @objc private func toggleScreenCapture() {
        edgeLightManager?.toggleScreenCapture()
    }

    @objc private func toggleDesktopIcons() {
        edgeLightManager?.toggleDesktopIcons()
    }

    @objc private func toggleControls() {
        edgeLightManager?.toggleControlPanel()
    }

    @objc private func toggleLaunchAtLogin() {
        let settings = AppSettings.shared
        let newValue = !settings.launchAtLogin
        settings.launchAtLogin = newValue
        LoginItemManager.shared.setLaunchAtLogin(enabled: newValue)
        launchAtLoginItem?.state = newValue ? .on : .off
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
