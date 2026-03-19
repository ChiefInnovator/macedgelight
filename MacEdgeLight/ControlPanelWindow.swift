import Cocoa

class ControlPanelWindow: NSPanel {
    private weak var edgeLightManager: EdgeLightManager?
    private var hideTimer: Timer?
    private let autoHideDelay: TimeInterval = 3.0
    private let activeColor = NSColor.systemCyan
    private var toggleButtons: [String: NSButton] = [:]

    init(manager: EdgeLightManager) {
        self.edgeLightManager = manager

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true

        setupUI()
    }

    private func setupUI() {
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 380, height: 44))
        container.material = .hudWindow
        container.state = .active
        container.blendingMode = .behindWindow
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true

        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let buttonDefs: [(String, String, Selector)] = [
            ("sun.min", "Decrease brightness (Cmd+Shift+Down)", #selector(brightnessDown)),
            ("sun.max", "Increase brightness (Cmd+Shift+Up)", #selector(brightnessUp)),
            ("flame", "Make light warmer", #selector(colorWarmer)),
            ("snowflake", "Make light cooler", #selector(colorCooler)),
            ("lightbulb", "Toggle light (Cmd+Shift+L)", #selector(toggleLight)),
            ("display", "Switch monitor", #selector(switchMonitor)),
            ("display.2", "All monitors", #selector(allMonitors)),
            ("menubar.rectangle", "Toggle light over menu bar", #selector(toggleMenuBarOverlay)),
            ("circle.dashed", "Cursor reveal", #selector(toggleCursorReveal)),
            ("eye.slash", "Show/hide desktop icons", #selector(toggleDesktopIcons)),
            ("xmark.circle", "Exit", #selector(exitApp)),
        ]

        var allConstraints: [NSLayoutConstraint] = []

        for (imageName, tooltip, action) in buttonDefs {
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 36))
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

            if ["lightbulb", "display.2", "menubar.rectangle", "circle.dashed", "eye.slash"].contains(imageName) {
                toggleButtons[imageName] = button
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
        toggleButtons["lightbulb"]?.contentTintColor = settings.isLightOn ? activeColor : .white
        toggleButtons["display.2"]?.contentTintColor = settings.showOnAllMonitors ? activeColor : .white
        toggleButtons["menubar.rectangle"]?.contentTintColor = settings.extendOverMenuBar ? activeColor : .white
        toggleButtons["circle.dashed"]?.contentTintColor = settings.cursorRevealEnabled ? activeColor : .white
        toggleButtons["eye.slash"]?.contentTintColor = settings.desktopIconsHidden ? activeColor : .white
    }

    func positionOnScreen(_ screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.origin.y + 80
        setFrameOrigin(NSPoint(x: x, y: y))
    }

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

    @objc private func toggleDesktopIcons() {
        edgeLightManager?.toggleDesktopIcons()
    }

    @objc private func exitApp() {
        NSApplication.shared.terminate(nil)
    }
}
