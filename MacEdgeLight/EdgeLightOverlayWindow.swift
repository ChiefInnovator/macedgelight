import Cocoa

class EdgeLightOverlayWindow: NSWindow {
    let edgeLightView: EdgeLightView
    private var cursorTrackingTimer: Timer?

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

        // Exclude from screen capture (like the Windows WDA_EXCLUDEFROMCAPTURE)
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

        // Shift the light frame below the menu bar, or extend over it
        if settings.extendOverMenuBar {
            self.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
            edgeLightView.topInset = 0
        } else {
            self.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
            let menuBarHeight = (self.screen ?? NSScreen.main)
                .map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 25
            edgeLightView.topInset = menuBarHeight
        }

        // Cursor reveal
        edgeLightView.cursorRevealEnabled = settings.cursorRevealEnabled
        if settings.cursorRevealEnabled {
            startCursorTracking()
        } else {
            stopCursorTracking()
            edgeLightView.cursorPosition = nil
        }
    }

    // MARK: - Cursor Tracking

    private func startCursorTracking() {
        guard cursorTrackingTimer == nil else { return }
        cursorTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateCursorPosition()
        }
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
