import Cocoa

class MagnifierWindow: NSPanel {
    private let magnifierView: MagnifierView
    private var trackingTimer: Timer?
    private let magnification: CGFloat = 2.0
    private let captureSize: CGFloat = 200 // points to capture around cursor

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let aspect = screen.frame.width / screen.frame.height
        let windowHeight: CGFloat = 280
        let windowWidth = round(windowHeight * aspect)

        magnifierView = MagnifierView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.ignoresMouseEvents = true
        self.contentView = magnifierView
    }

    func startTracking() {
        guard trackingTimer == nil else { return }
        updateCapture()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updateCapture()
        }
        RunLoop.current.add(timer, forMode: .common)
        trackingTimer = timer
    }

    func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
    }

    private func updateCapture() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = screenContainingPoint(mouseLocation) else { return }

        // Resize window if screen aspect ratio changed
        let aspect = screen.frame.width / screen.frame.height
        let windowHeight = frame.height
        let windowWidth = round(windowHeight * aspect)
        if abs(frame.width - windowWidth) > 1 {
            let newFrame = NSRect(x: frame.origin.x, y: frame.origin.y, width: windowWidth, height: windowHeight)
            setFrame(newFrame, display: false)
            magnifierView.frame = NSRect(origin: .zero, size: newFrame.size)
        }

        // Position window offset from cursor
        let offset: CGFloat = 30
        var windowOrigin = NSPoint(
            x: mouseLocation.x + offset,
            y: mouseLocation.y + offset
        )

        // Keep window on screen
        let screenFrame = screen.frame
        if windowOrigin.x + frame.width > screenFrame.maxX {
            windowOrigin.x = mouseLocation.x - offset - frame.width
        }
        if windowOrigin.y + frame.height > screenFrame.maxY {
            windowOrigin.y = mouseLocation.y - offset - frame.height
        }
        if windowOrigin.x < screenFrame.minX {
            windowOrigin.x = screenFrame.minX
        }
        if windowOrigin.y < screenFrame.minY {
            windowOrigin.y = screenFrame.minY
        }
        setFrameOrigin(windowOrigin)

        // Convert mouse location to CGPoint in screen capture coordinates
        // NSEvent.mouseLocation uses bottom-left origin; CGWindowList uses top-left
        let mainHeight = NSScreen.screens.map { $0.frame.maxY }.max() ?? screen.frame.height
        let captureWidth = frame.width / magnification
        let captureHeight = frame.height / magnification
        let captureRect = CGRect(
            x: mouseLocation.x - captureWidth / 2,
            y: mainHeight - mouseLocation.y - captureHeight / 2,
            width: captureWidth,
            height: captureHeight
        )

        // Capture screen content (excluding this window)
        if let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenBelowWindow,
            CGWindowID(self.windowNumber),
            [.bestResolution]
        ) {
            magnifierView.capturedImage = cgImage
            magnifierView.needsDisplay = true
        }
    }

    private func screenContainingPoint(_ point: NSPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main
    }
}

private class MagnifierView: NSView {
    var capturedImage: CGImage?
    private let cornerRadius: CGFloat = 12
    private let borderWidth: CGFloat = 2
    private let crosshairSize: CGFloat = 12

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let insetRect = bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let path = CGPath(roundedRect: insetRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        // Clip to rounded rect
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        // Draw captured image
        if let image = capturedImage {
            let drawRect = bounds.insetBy(dx: borderWidth, dy: borderWidth)
            ctx.draw(image, in: drawRect)
        } else {
            ctx.setFillColor(NSColor(white: 0.1, alpha: 0.9).cgColor)
            ctx.fill(bounds)
        }

        // Draw crosshair at center
        let cx = bounds.midX
        let cy = bounds.midY
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1.0)

        ctx.move(to: CGPoint(x: cx - crosshairSize, y: cy))
        ctx.addLine(to: CGPoint(x: cx - 3, y: cy))
        ctx.move(to: CGPoint(x: cx + 3, y: cy))
        ctx.addLine(to: CGPoint(x: cx + crosshairSize, y: cy))
        ctx.move(to: CGPoint(x: cx, y: cy - crosshairSize))
        ctx.addLine(to: CGPoint(x: cx, y: cy - 3))
        ctx.move(to: CGPoint(x: cx, y: cy + 3))
        ctx.addLine(to: CGPoint(x: cx, y: cy + crosshairSize))
        ctx.strokePath()

        ctx.restoreGState()

        // Draw border
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(borderWidth)
        ctx.strokePath()
    }
}
