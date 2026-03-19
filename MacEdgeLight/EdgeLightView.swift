import Cocoa
import QuartzCore

class EdgeLightView: NSView {
    // Target values (set externally)
    var brightness: Double = 1.0 {
        didSet { startAnimationIfNeeded() }
    }

    var colorTemperature: Double = 0.5 {
        didSet { startAnimationIfNeeded() }
    }

    var isLightOn: Bool = true {
        didSet { startAnimationIfNeeded() }
    }

    var topInset: CGFloat = 0 {
        didSet { startAnimationIfNeeded() }
    }

    // Cursor reveal cutout
    var cursorRevealEnabled: Bool = false
    var cursorPosition: NSPoint? {
        didSet { needsDisplay = true }
    }
    private let cursorRevealRadius: CGFloat = 60

    // Animated values used for drawing
    private var displayedBrightness: Double = 1.0
    private var displayedColorTemperature: Double = 0.5
    private var displayedTopInset: CGFloat = 0

    private var animationTimer: Timer?
    private let lerpSpeed: Double = 0.12 // per-frame lerp factor (~0.3s to settle)

    private let frameThickness: CGFloat = 60
    private let outerCornerRadius: CGFloat = 20
    private let innerCornerRadius: CGFloat = 12
    private let glowRadius: CGFloat = 40

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override var isFlipped: Bool { false }

    // MARK: - Animation

    private func startAnimationIfNeeded() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.animationTick()
        }
    }

    private func animationTick() {
        let targetBrightness = isLightOn ? brightness : 0.0
        let targetColorTemp = colorTemperature
        let targetInset = topInset

        displayedBrightness += (targetBrightness - displayedBrightness) * lerpSpeed
        displayedColorTemperature += (targetColorTemp - displayedColorTemperature) * lerpSpeed
        displayedTopInset += (targetInset - displayedTopInset) * CGFloat(lerpSpeed)

        let brightnessSettled = abs(displayedBrightness - targetBrightness) < 0.002
        let colorSettled = abs(displayedColorTemperature - targetColorTemp) < 0.002
        let insetSettled = abs(displayedTopInset - targetInset) < 0.5

        if brightnessSettled { displayedBrightness = targetBrightness }
        if colorSettled { displayedColorTemperature = targetColorTemp }
        if insetSettled { displayedTopInset = targetInset }

        needsDisplay = true

        if brightnessSettled && colorSettled && insetSettled {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    // MARK: - Drawing

    private func colorForTemperature() -> NSColor {
        let t = displayedColorTemperature
        let r = 220.0 + (255.0 - 220.0) * t
        let g = 235.0 + (220.0 - 235.0) * t
        let b = 255.0 + (180.0 - 255.0) * t
        return NSColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: 1.0)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Skip drawing when fully faded out
        guard displayedBrightness > 0.002 else { return }

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()

        // When not extending over the menu bar, shift the top edge down
        var drawBounds = self.bounds
        drawBounds.size.height -= displayedTopInset

        // Outer rounded rect
        let outerRect = drawBounds
        let outerPath = CGPath(roundedRect: outerRect, cornerWidth: outerCornerRadius, cornerHeight: outerCornerRadius, transform: nil)

        // Inner rounded rect (the transparent hole)
        let innerRect = drawBounds.insetBy(dx: frameThickness, dy: frameThickness)
        let innerPath = CGPath(roundedRect: innerRect, cornerWidth: innerCornerRadius, cornerHeight: innerCornerRadius, transform: nil)

        // Create frame path (outer minus inner)
        let framePath = CGMutablePath()
        framePath.addPath(outerPath)
        framePath.addPath(innerPath)

        let baseColor = colorForTemperature()
        let alpha = min(CGFloat(displayedBrightness), 1.0)
        let fillColor = baseColor.withAlphaComponent(alpha)

        // Draw the glow effect using multiple passes with decreasing alpha
        // Outer glow
        for i in stride(from: glowRadius, through: 1, by: -2) {
            let glowAlpha = alpha * CGFloat(0.03) * (1.0 - CGFloat(i) / glowRadius)
            let glowColor = baseColor.withAlphaComponent(glowAlpha)

            let expandedOuter = drawBounds.insetBy(dx: -i, dy: -i)
            let expandedOuterPath = CGPath(roundedRect: expandedOuter, cornerWidth: outerCornerRadius + i, cornerHeight: outerCornerRadius + i, transform: nil)

            let contractedInner = innerRect.insetBy(dx: i, dy: i)
            if contractedInner.width > 0 && contractedInner.height > 0 {
                let contractedInnerPath = CGPath(roundedRect: contractedInner, cornerWidth: max(0, innerCornerRadius - i), cornerHeight: max(0, innerCornerRadius - i), transform: nil)

                let glowFrame = CGMutablePath()
                glowFrame.addPath(expandedOuterPath)
                glowFrame.addPath(contractedInnerPath)

                context.setFillColor(glowColor.cgColor)
                context.addPath(glowFrame)
                context.fillPath(using: .evenOdd)
            }
        }

        // Draw the solid frame with gradient
        context.addPath(framePath)
        context.clip(using: .evenOdd)

        // Gradient from top-left to bottom-right (matching Windows version)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let white = NSColor.white.withAlphaComponent(alpha)
        let tinted = fillColor
        let slightlyDimmed = baseColor.withAlphaComponent(alpha * 0.94)

        let colors = [
            white.cgColor,
            slightlyDimmed.cgColor,
            tinted.cgColor,
            slightlyDimmed.cgColor,
            white.cgColor
        ] as CFArray

        let locations: [CGFloat] = [0.0, 0.3, 0.5, 0.7, 1.0]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: drawBounds.minX, y: drawBounds.maxY),
                end: CGPoint(x: drawBounds.maxX, y: drawBounds.minY),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        // Inner glow (soft light bleeding inward)
        context.resetClip()
        for i in stride(from: glowRadius * 0.6, through: 1, by: -2) {
            let glowAlpha = alpha * CGFloat(0.04) * (1.0 - CGFloat(i) / (glowRadius * 0.6))
            let glowColor = baseColor.withAlphaComponent(glowAlpha)

            let shrunkInner = innerRect.insetBy(dx: -i, dy: -i)
            let shrunkInnerPath = CGPath(roundedRect: shrunkInner, cornerWidth: innerCornerRadius + i, cornerHeight: innerCornerRadius + i, transform: nil)

            let deeperInner = innerRect.insetBy(dx: i * 0.3, dy: i * 0.3)
            if deeperInner.width > 0 && deeperInner.height > 0 {
                let deeperPath = CGPath(roundedRect: deeperInner, cornerWidth: max(0, innerCornerRadius - i * 0.3), cornerHeight: max(0, innerCornerRadius - i * 0.3), transform: nil)

                let innerGlow = CGMutablePath()
                innerGlow.addPath(shrunkInnerPath)
                innerGlow.addPath(deeperPath)

                context.setFillColor(glowColor.cgColor)
                context.addPath(innerGlow)
                context.fillPath(using: .evenOdd)
            }
        }

        // Bloom: additive passes when brightness exceeds 1.0
        let bloom = CGFloat(displayedBrightness) - 1.0
        if bloom > 0 {
            context.setBlendMode(.plusLighter)
            let bloomAlpha = min(bloom, 1.0)

            // Additive frame fill (white-hot bloom over the solid frame)
            context.addPath(framePath)
            context.clip(using: .evenOdd)
            context.setFillColor(NSColor.white.withAlphaComponent(bloomAlpha * 0.6).cgColor)
            context.fill(drawBounds)
            context.resetClip()

            // Additive outer glow bloom (wider, brighter glow spill)
            let bloomRadius = glowRadius + glowRadius * bloom
            for i in stride(from: bloomRadius, through: 2, by: -4) {
                let glowAlpha = bloomAlpha * 0.05 * (1.0 - i / bloomRadius)
                let expandedOuter = drawBounds.insetBy(dx: -i, dy: -i)
                let expandedOuterPath = CGPath(roundedRect: expandedOuter, cornerWidth: outerCornerRadius + i, cornerHeight: outerCornerRadius + i, transform: nil)
                let contractedInner = innerRect.insetBy(dx: i, dy: i)
                if contractedInner.width > 0 && contractedInner.height > 0 {
                    let contractedInnerPath = CGPath(roundedRect: contractedInner, cornerWidth: max(0, innerCornerRadius - i), cornerHeight: max(0, innerCornerRadius - i), transform: nil)
                    let bloomFrame = CGMutablePath()
                    bloomFrame.addPath(expandedOuterPath)
                    bloomFrame.addPath(contractedInnerPath)
                    context.setFillColor(NSColor.white.withAlphaComponent(glowAlpha).cgColor)
                    context.addPath(bloomFrame)
                    context.fillPath(using: .evenOdd)
                }
            }

            context.setBlendMode(.normal)
        }

        // Cursor reveal: punch a feathered circle through the light
        if cursorRevealEnabled, let pos = cursorPosition {
            context.setBlendMode(.destinationOut)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let cutoutColors = [
                NSColor.black.withAlphaComponent(1.0).cgColor,
                NSColor.black.withAlphaComponent(1.0).cgColor,
                NSColor.black.withAlphaComponent(0.0).cgColor,
            ] as CFArray
            let cutoutLocations: [CGFloat] = [0.0, 0.5, 1.0]
            if let cutoutGradient = CGGradient(colorsSpace: colorSpace, colors: cutoutColors, locations: cutoutLocations) {
                context.drawRadialGradient(
                    cutoutGradient,
                    startCenter: pos, startRadius: 0,
                    endCenter: pos, endRadius: cursorRevealRadius,
                    options: []
                )
            }
        }

        context.restoreGState()
    }
}
