import Cocoa

// Button that fires its action immediately on press, then repeats with fine steps while held
private class RepeatButton: NSButton {
    var onHoldTick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        // Fire immediately on press (normal step via target/action)
        _ = target?.perform(action, with: self)

        let holdDelay: TimeInterval = 0.25   // pause before repeat starts
        let repeatInterval: TimeInterval = 0.035
        let pressTime = Date()
        var lastRepeat = pressTime

        // Track mouse until release; fire fine-step ticks while held.
        // Using the 4-param nextEvent with a short timeout so the loop
        // keeps running (the 2-param version blocks the entire run loop).
        while true {
            guard let window = self.window else { break }
            if let next = window.nextEvent(
                matching: [.leftMouseUp, .leftMouseDragged],
                until: Date(timeIntervalSinceNow: repeatInterval),
                inMode: .eventTracking,
                dequeue: true
            ) {
                if next.type == .leftMouseUp { break }
            }

            let now = Date()
            if now.timeIntervalSince(pressTime) >= holdDelay,
               now.timeIntervalSince(lastRepeat) >= repeatInterval {
                onHoldTick?()
                lastRepeat = now
            }
        }
    }
}

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

class ControlPanelWindow: NSPanel {
    private weak var edgeLightManager: EdgeLightManager?
    private var hideTimer: Timer?
    private let autoHideDelay: TimeInterval = 3.0
    private let activeColor = NSColor.white
    private var toggleButtons: [String: NSButton] = [:]
    private var lightDependentButtons: [NSButton] = []
    private weak var containerView: NSVisualEffectView?

    init(manager: EdgeLightManager) {
        self.edgeLightManager = manager

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 616, height: 44),
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

        setupUI()
    }

    private func setupUI() {
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 616, height: 44))
        container.material = .hudWindow
        container.state = .active
        container.blendingMode = .behindWindow
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        self.containerView = container

        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Buttons that repeat while held use RepeatButton; others use standard NSButton
        let repeatIcons: Set<String> = ["sun.min", "sun.max", "flame", "snowflake", "rectangle.compress.vertical", "rectangle.expand.vertical"]

        let buttonDefs: [(String, String, Selector)] = [
            ("sun.min", "Brightness Down (Cmd+Shift+Down) — hold to repeat", #selector(brightnessDown)),
            ("sun.max", "Brightness Up (Cmd+Shift+Up) — hold to repeat", #selector(brightnessUp)),
            ("flame", "Warmer — hold to repeat", #selector(colorWarmer)),
            ("snowflake", "Cooler — hold to repeat", #selector(colorCooler)),
            ("rectangle.compress.vertical", "Thinner Border — hold to repeat", #selector(borderThinner)),
            ("rectangle.expand.vertical", "Thicker Border — hold to repeat", #selector(borderThicker)),
            ("lightbulb", "Toggle Light (Cmd+Shift+L) — double-click to reset", #selector(toggleLight)),
            ("display", "Next Monitor", #selector(switchMonitor)),
            ("display.2", "All Monitors", #selector(allMonitors)),
            ("menubar.rectangle", "Extend Over Menu Bar", #selector(toggleMenuBarOverlay)),
            ("circle.dashed", "Cursor Reveal", #selector(toggleCursorReveal)),
            ("video", "Show in Screen Capture", #selector(toggleScreenCapture)),
            ("eye.slash", "Hide Desktop Icons", #selector(toggleDesktopIcons)),
            ("arrow.counterclockwise", "Reset to Defaults", #selector(resetDefaults)),
            ("xmark.circle", "Quit Mac Edge Light", #selector(exitApp)),
        ]

        var allConstraints: [NSLayoutConstraint] = []

        for (imageName, tooltip, action) in buttonDefs {
            let button: NSButton
            if repeatIcons.contains(imageName) {
                let rb = RepeatButton(frame: NSRect(x: 0, y: 0, width: 36, height: 36))
                // Map each repeat button to its fine-step closure
                switch imageName {
                case "sun.min":
                    rb.onHoldTick = { [weak self] in self?.edgeLightManager?.decreaseBrightnessFine() }
                case "sun.max":
                    rb.onHoldTick = { [weak self] in self?.edgeLightManager?.increaseBrightnessFine() }
                case "flame":
                    rb.onHoldTick = { [weak self] in self?.edgeLightManager?.increaseColorTemperatureFine() }
                case "snowflake":
                    rb.onHoldTick = { [weak self] in self?.edgeLightManager?.decreaseColorTemperatureFine() }
                case "rectangle.compress.vertical":
                    rb.onHoldTick = { [weak self] in self?.edgeLightManager?.decreaseBorderWidthFine() }
                case "rectangle.expand.vertical":
                    rb.onHoldTick = { [weak self] in self?.edgeLightManager?.increaseBorderWidthFine() }
                default: break
                }
                button = rb
            } else if imageName == "lightbulb" {
                let db = DoubleClickButton(frame: NSRect(x: 0, y: 0, width: 36, height: 36))
                db.onDoubleClick = { [weak self] in self?.edgeLightManager?.resetToDefaults() }
                button = db
            } else {
                button = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 36))
            }

            button.bezelStyle = .accessoryBarAction
            button.isBordered = false
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: tooltip)
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = tooltip
            button.target = self
            button.action = action
            button.contentTintColor = .white

            allConstraints.append(button.widthAnchor.constraint(equalToConstant: 36))
            allConstraints.append(button.heightAnchor.constraint(equalToConstant: 36))

            if ["lightbulb", "display.2", "menubar.rectangle", "circle.dashed", "video", "eye.slash"].contains(imageName) {
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
        hideTimer?.invalidate()
        hideTimer = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0.6
        }
        startHideTimer()
    }

    func updateToggleStates() {
        let settings = AppSettings.shared

        setToggle("lightbulb", active: settings.isLightOn,
                  onIcon: "lightbulb.fill", offIcon: "lightbulb")
        setToggle("display.2", active: settings.showOnAllMonitors,
                  onIcon: "rectangle.fill.on.rectangle.fill", offIcon: "rectangle.on.rectangle")
        setToggle("menubar.rectangle", active: settings.extendOverMenuBar,
                  onIcon: "menubar.rectangle", offIcon: "menubar.rectangle")
        setToggle("circle.dashed", active: settings.cursorRevealEnabled,
                  onIcon: "circle.fill", offIcon: "circle.dashed")
        setToggle("video", active: settings.visibleInCapture,
                  onIcon: "video.fill", offIcon: "video.slash")
        setToggle("eye.slash", active: settings.desktopIconsHidden,
                  onIcon: "eye.slash", offIcon: "eye")

        // Disable controls that don't apply when the light is off
        let dimColor = NSColor(white: 1.0, alpha: 0.25)
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
                layer.backgroundColor = nil
            }
        }
    }

    private func setToggle(_ key: String, active: Bool, onIcon: String, offIcon: String) {
        guard let button = toggleButtons[key] else { return }
        let iconName = active ? onIcon : offIcon
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: button.toolTip)
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
        edgeLightManager?.toggleExtendOverMenuBar()
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

    @objc private func resetDefaults() {
        edgeLightManager?.resetToDefaults()
    }

    @objc private func exitApp() {
        NSApplication.shared.terminate(nil)
    }
}
