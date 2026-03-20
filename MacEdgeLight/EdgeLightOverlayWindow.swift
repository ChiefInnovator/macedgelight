import Cocoa

class EdgeLightOverlayWindow: NSWindow {
    let edgeLightView: EdgeLightView
    private var cursorTrackingTimer: Timer?
    private var menuBarTrackingTimer: Timer?
    private var menuBarRevealed: Bool = false
    private var menuBarHeight: CGFloat = 25

    convenience init(for screen: NSScreen) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.setFrame(screen.frame, display: false)
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        edgeLightView = EdgeLightView(frame: NSRect(origin: .zero, size: contentRect.size))

        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )

        // Transparent, click-through overlay
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        // Use a level below the menu bar so the Finder menu auto-shows
        // when the cursor moves to the top of the screen.
        // .mainMenu is 24; we sit just below it but above floating windows (3).
        self.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.isReleasedWhenClosed = false

        // Default: exclude from screen capture (togglable via settings)
        self.sharingType = .none

        self.contentView = edgeLightView
    }

    func updateForScreen(_ screen: NSScreen) {
        self.setFrame(screen.frame, display: true)
        edgeLightView.frame = NSRect(origin: .zero, size: screen.frame.size)
        edgeLightView.needsDisplay = true
    }

    func applySettings(_ settings: AppSettings) {
        edgeLightView.brightness = settings.brightness
        edgeLightView.colorTemperature = settings.colorTemperature
        edgeLightView.isLightOn = settings.isLightOn
        edgeLightView.frameThickness = CGFloat(settings.borderWidth)

        // Menu bar mode: 0 = below, 1 = extend over, 2 = auto reveal on hover
        let menuBarH = (self.screen ?? NSScreen.main)
            .map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 25
        self.menuBarHeight = menuBarH

        switch settings.menuBarMode {
        case 1: // Extend
            self.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
            edgeLightView.topInset = 0
            stopMenuBarTracking()
        case 2: // Auto
            self.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
            if !menuBarRevealed {
                edgeLightView.topInset = 0
            }
            startMenuBarTracking()
        default: // 0: Below
            self.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
            edgeLightView.topInset = menuBarH
            stopMenuBarTracking()
        }

        // Screen capture visibility
        self.sharingType = settings.visibleInCapture ? .readOnly : .none

        // Cursor reveal
        edgeLightView.cursorRevealEnabled = settings.cursorRevealEnabled
        if settings.cursorRevealEnabled {
            startCursorTracking()
        } else {
            stopCursorTracking()
            edgeLightView.cursorPosition = nil
        }
    }

    // MARK: - Menu Bar Auto-Reveal

    private func startMenuBarTracking() {
        guard menuBarTrackingTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updateMenuBarReveal()
        }
        RunLoop.current.add(timer, forMode: .common)
        menuBarTrackingTimer = timer
    }

    private func stopMenuBarTracking() {
        menuBarTrackingTimer?.invalidate()
        menuBarTrackingTimer = nil
        menuBarRevealed = false
    }

    private func updateMenuBarReveal() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = self.screen ?? NSScreen.main else { return }

        // Cursor is in the menu bar if it's at or above the top of the visible area
        // and within this screen's horizontal bounds
        let cursorInMenuBar = mouseLocation.y >= screen.visibleFrame.maxY
            && mouseLocation.x >= screen.frame.minX
            && mouseLocation.x <= screen.frame.maxX

        if cursorInMenuBar && !menuBarRevealed {
            menuBarRevealed = true
            edgeLightView.topInset = menuBarHeight
        } else if !cursorInMenuBar && menuBarRevealed {
            menuBarRevealed = false
            edgeLightView.topInset = 0
        }
    }

    // MARK: - Cursor Tracking

    private func startCursorTracking() {
        guard cursorTrackingTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateCursorPosition()
        }
        RunLoop.current.add(timer, forMode: .common)
        cursorTrackingTimer = timer
    }

    private func stopCursorTracking() {
        cursorTrackingTimer?.invalidate()
        cursorTrackingTimer = nil
    }

    private func updateCursorPosition() {
        let mouseLocation = NSEvent.mouseLocation
        if frame.contains(mouseLocation) {
            let viewPoint = NSPoint(
                x: mouseLocation.x - frame.origin.x,
                y: mouseLocation.y - frame.origin.y
            )
            edgeLightView.cursorPosition = viewPoint
        } else {
            if edgeLightView.cursorPosition != nil {
                edgeLightView.cursorPosition = nil
            }
        }
    }
}
