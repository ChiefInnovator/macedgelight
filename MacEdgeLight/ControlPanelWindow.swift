import Cocoa

// Button that detects double-click separately from single-click
private class DoubleClickButton: NSButton {
    var onDoubleClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
}

private class DraggableVisualEffectView: NSVisualEffectView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private class DraggableStackView: NSStackView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

class ControlPanelWindow: NSPanel {
    private weak var edgeLightManager: EdgeLightManager?
    private var hideTimer: Timer?
    private let autoHideDelay: TimeInterval = 3.0
    private let activeColor = NSColor.white
    private var toggleButtons: [String: NSButton] = [:]
    private var lightDependentButtons: [NSButton] = []
    private weak var containerView: NSVisualEffectView?
    private var tooltipWindow: NSWindow?
    private var tooltipTimer: Timer?

    init(manager: EdgeLightManager) {
        self.edgeLightManager = manager

        // Width is set after setupUI to fit the actual button count
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        // Must be above the overlay (which sits near .mainMenu level)
        self.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.acceptsMouseMovedEvents = true

        setupUI()

        // Size window to fit its content
        if let contentView = self.contentView {
            contentView.layoutSubtreeIfNeeded()
            let fittingSize = contentView.fittingSize
            self.setContentSize(NSSize(width: fittingSize.width, height: 52))
        }
    }

    override var canBecomeKey: Bool { true }

    private func setupUI() {
        let container = DraggableVisualEffectView(frame: NSRect(x: 0, y: 0, width: 100, height: 52))
        container.material = .dark
        container.state = .active
        container.blendingMode = .behindWindow
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.95).cgColor
        self.containerView = container

        let stackView = DraggableStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false


        // Light-dependent controls are dimmed when light is off;
        // always-active controls are grouped after the separator.
        let alwaysActiveStart = "lightbulb"
        let buttonDefs: [(String, String, Selector)] = [
            ("sun.min", "Brightness Down (Cmd+Shift+Down)", #selector(brightnessDown)),
            ("sun.max", "Brightness Up (Cmd+Shift+Up)", #selector(brightnessUp)),
            ("flame", "Warmer", #selector(colorWarmer)),
            ("snowflake", "Cooler", #selector(colorCooler)),
            ("rectangle.compress.vertical", "Thinner Border", #selector(borderThinner)),
            ("rectangle.expand.vertical", "Thicker Border", #selector(borderThicker)),
            ("display", "Next Monitor", #selector(switchMonitor)),
            ("display.2", "All Monitors", #selector(allMonitors)),
            ("menubar.rectangle", "Extend Over Menu Bar", #selector(toggleMenuBarOverlay)),
            ("circle.dashed", "Cursor Reveal", #selector(toggleCursorReveal)),
            ("video", "Show in Screen Capture", #selector(toggleScreenCapture)),
            // Always-active controls
            ("lightbulb", "Toggle Light (Cmd+Shift+L) — double-click to reset", #selector(toggleLight)),
            ("sun.max.trianglebadge.exclamationmark", "Display Brightness Boost", #selector(toggleDisplayBrightness)),
            ("plus.magnifyingglass", "Magnifier", #selector(toggleMagnifier)),
            ("eye.slash", "Hide Desktop Icons", #selector(toggleDesktopIcons)),
            ("arrow.counterclockwise", "Reset to Defaults", #selector(resetDefaults)),
            ("xmark.circle", "Hide Controls", #selector(hideControls)),
        ]

        var allConstraints: [NSLayoutConstraint] = []

        for (imageName, tooltip, action) in buttonDefs {
            // Insert a visual separator before the always-active group
            if imageName == alwaysActiveStart {
                let sep = NSView()
                sep.wantsLayer = true
                sep.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.3).cgColor
                sep.translatesAutoresizingMaskIntoConstraints = false
                stackView.addArrangedSubview(sep)
                allConstraints.append(sep.widthAnchor.constraint(equalToConstant: 1))
                allConstraints.append(sep.heightAnchor.constraint(equalToConstant: 24))
            }

            let button: NSButton
            if imageName == "lightbulb" {
                let db = DoubleClickButton(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
                db.onDoubleClick = { [weak self] in self?.edgeLightManager?.resetToDefaults() }
                button = db
            } else {
                button = NSButton(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
            }

            button.bezelStyle = .accessoryBarAction
            button.isBordered = false
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: tooltip)
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = tooltip
            button.addTrackingArea(NSTrackingArea(
                rect: button.bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: ["button": button]
            ))
            button.target = self
            button.action = action
            button.contentTintColor = .white

            allConstraints.append(button.widthAnchor.constraint(equalToConstant: 44))
            allConstraints.append(button.heightAnchor.constraint(equalToConstant: 44))

            if ["lightbulb", "display.2", "menubar.rectangle", "circle.dashed", "plus.magnifyingglass", "video", "eye.slash", "bolt.circle", "sun.max.trianglebadge.exclamationmark"].contains(imageName) {
                toggleButtons[imageName] = button
            }

            if ["sun.min", "sun.max", "flame", "snowflake", "rectangle.compress.vertical", "rectangle.expand.vertical", "display", "display.2", "menubar.rectangle", "circle.dashed", "video"].contains(imageName) {
                lightDependentButtons.append(button)
            }

            stackView.addArrangedSubview(button)
        }

        container.addSubview(stackView)

        allConstraints.append(contentsOf: [
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        NSLayoutConstraint.activate(allConstraints)

        self.contentView = container

        // Track mouse for opacity changes
        let trackingArea = NSTrackingArea(
            rect: container.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        container.addTrackingArea(trackingArea)

        // Start visible, then auto-hide after delay
        self.alphaValue = 0.6
        startHideTimer()
    }

    // MARK: - Auto-hide

    private func startHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            self?.autoHide()
        }
    }

    private func autoHide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.animator().alphaValue = 0.01
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if let button = event.trackingArea?.userInfo?["button"] as? NSButton,
           let tooltip = button.toolTip {
            showTooltip(tooltip, near: event)
        } else {
            // Container tracking area — show the panel
            hideTimer?.invalidate()
            hideTimer = nil
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.animator().alphaValue = 1.0
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        if event.trackingArea?.userInfo?["button"] != nil {
            hideTooltip()
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.animator().alphaValue = 0.6
            }
            startHideTimer()
        }
    }

    private func showTooltip(_ text: String, near event: NSEvent) {
        tooltipTimer?.invalidate()
        tooltipTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = .white
            label.backgroundColor = NSColor(white: 0, alpha: 0.85)
            label.isBezeled = false
            label.sizeToFit()

            let padding: CGFloat = 8
            let w = label.frame.width + padding * 2
            let h = label.frame.height + padding

            let tip = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                               styleMask: .borderless, backing: .buffered, defer: false)
            tip.isOpaque = false
            tip.backgroundColor = NSColor(white: 0, alpha: 0.85)
            tip.level = NSWindow.Level(rawValue: self.level.rawValue + 1)
            tip.ignoresMouseEvents = true
            tip.hasShadow = true
            label.frame.origin = CGPoint(x: padding, y: padding / 2)
            tip.contentView?.addSubview(label)

            // Position above the button
            let screenPoint = event.locationInWindow
            let windowPoint = self.convertPoint(toScreen: screenPoint)
            tip.setFrameOrigin(NSPoint(x: windowPoint.x - w / 2, y: self.frame.maxY + 4))

            tip.orderFront(nil)
            self.tooltipWindow?.orderOut(nil)
            self.tooltipWindow = tip
        }
    }

    private func hideTooltip() {
        tooltipTimer?.invalidate()
        tooltipTimer = nil
        tooltipWindow?.orderOut(nil)
        tooltipWindow = nil
    }

    func updateToggleStates() {
        let settings = AppSettings.shared

        setToggle("lightbulb", active: settings.isLightOn,
                  onIcon: "lightbulb.fill", offIcon: "lightbulb")
        setToggle("display.2", active: settings.showOnAllMonitors,
                  onIcon: "rectangle.fill.on.rectangle.fill", offIcon: "rectangle.on.rectangle")
        updateMenuBarModeButton(settings)
        setToggle("circle.dashed", active: settings.cursorRevealEnabled,
                  onIcon: "circle.fill", offIcon: "circle.dashed")
        setToggle("plus.magnifyingglass", active: settings.magnifierEnabled,
                  onIcon: "plus.magnifyingglass", offIcon: "minus.magnifyingglass")
        setToggle("video", active: settings.visibleInCapture,
                  onIcon: "video.fill", offIcon: "video.slash")
        setToggle("eye.slash", active: settings.desktopIconsHidden,
                  onIcon: "eye.slash", offIcon: "eye")
        toggleButtons["eye.slash"]?.toolTip = settings.desktopIconsHidden
            ? "Show Desktop Icons" : "Hide Desktop Icons"
        setToggle("sun.max.trianglebadge.exclamationmark", active: DisplayBrightnessManager.shared.isBoosted,
                  onIcon: "sun.max.fill", offIcon: "sun.max")

        // Disable controls that don't apply when the light is off
        let dimColor = NSColor(white: 1.0, alpha: 0.4)
        for button in lightDependentButtons {
            button.isEnabled = settings.isLightOn
            button.contentTintColor = settings.isLightOn ? activeColor : dimColor
        }

        // Dynamically darken the panel background when the glow would overlap it.
        // The panel sits ~80pt from the bottom edge; a thicker/brighter glow needs
        // a more opaque backdrop so the controls remain readable.
        updateBackgroundForGlow(settings)
    }

    private func updateBackgroundForGlow(_ settings: AppSettings) {
        guard let layer = containerView?.layer else { return }
        if settings.isLightOn {
            // How much of the glow reaches the panel: border thickness + bloom glow spread
            let overlap = settings.borderWidth + max(0, settings.brightness - 1.0) * 40
            // Panel is ~80pt from bottom edge; glow starts mattering around 60pt
            let intensity = min(1.0, max(0, overlap - 40) / 100.0) * settings.brightness
            let alpha = CGFloat(min(0.85, intensity * 0.8))
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                layer.backgroundColor = NSColor(white: 0.05, alpha: alpha).cgColor
            }
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                layer.backgroundColor = NSColor(white: 0.1, alpha: 0.95).cgColor
            }
        }
    }

    private func setToggle(_ key: String, active: Bool, onIcon: String, offIcon: String) {
        guard let button = toggleButtons[key] else { return }
        let iconName = active ? onIcon : offIcon
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: button.toolTip)
        button.contentTintColor = activeColor
    }

    private func updateMenuBarModeButton(_ settings: AppSettings) {
        guard let button = toggleButtons["menubar.rectangle"] else { return }
        let iconName: String
        let tooltip: String
        switch settings.menuBarMode {
        case 1:
            iconName = "rectangle.topthird.inset.filled"
            tooltip = "Menu Bar: Extend (click to cycle)"
        case 2:
            iconName = "rectangle.arrowtriangle.2.outward"
            tooltip = "Menu Bar: Auto (click to cycle)"
        default:
            iconName = "menubar.rectangle"
            tooltip = "Menu Bar: Below (click to cycle)"
        }
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: tooltip)
        button.toolTip = tooltip
        button.contentTintColor = activeColor
    }

    func positionOnScreen(_ screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.origin.y + 80
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    // Single-click actions (also fires on first press for repeat buttons)
    @objc private func brightnessDown() {
        edgeLightManager?.decreaseBrightness()
    }

    @objc private func brightnessUp() {
        edgeLightManager?.increaseBrightness()
    }

    @objc private func colorWarmer() {
        edgeLightManager?.increaseColorTemperature()
    }

    @objc private func colorCooler() {
        edgeLightManager?.decreaseColorTemperature()
    }

    @objc private func borderThinner() {
        edgeLightManager?.decreaseBorderWidth()
    }

    @objc private func borderThicker() {
        edgeLightManager?.increaseBorderWidth()
    }

    @objc private func toggleLight() {
        edgeLightManager?.toggleLight()
    }

    @objc private func switchMonitor() {
        edgeLightManager?.moveToNextMonitor()
    }

    @objc private func allMonitors() {
        edgeLightManager?.toggleAllMonitors()
    }

    @objc private func toggleMenuBarOverlay() {
        edgeLightManager?.cycleMenuBarMode()
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

    @objc private func toggleDisplayBrightness() {
        edgeLightManager?.toggleDisplayBrightness()
    }

    @objc private func toggleLaunchAtLogin() {
        let settings = AppSettings.shared
        let newValue = !settings.launchAtLogin
        settings.launchAtLogin = newValue
        LoginItemManager.shared.setLaunchAtLogin(enabled: newValue)
    }

    @objc private func resetDefaults() {
        edgeLightManager?.resetToDefaults()
    }

    @objc private func hideControls() {
        edgeLightManager?.toggleControlPanel()
    }
}
