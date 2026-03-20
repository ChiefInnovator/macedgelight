#!/usr/bin/swift

import Cocoa

func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))

    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let bounds = CGRect(x: 0, y: 0, width: s, height: s)
    let iconInset = s * 0.02
    let iconRect = bounds.insetBy(dx: iconInset, dy: iconInset)
    let iconRadius = s * 0.185
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // Clip everything to the macOS rounded icon shape
    let iconPath = CGPath(roundedRect: iconRect, cornerWidth: iconRadius, cornerHeight: iconRadius, transform: nil)
    context.addPath(iconPath)
    context.clip()

    // Deep blue-purple desktop gradient
    let bgColors = [
        NSColor(red: 0.18, green: 0.15, blue: 0.32, alpha: 1.0).cgColor,
        NSColor(red: 0.10, green: 0.12, blue: 0.28, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.08, blue: 0.20, alpha: 1.0).cgColor,
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.5, 1.0]) {
        context.drawLinearGradient(bgGrad,
                                   start: CGPoint(x: s * 0.3, y: s),
                                   end: CGPoint(x: s * 0.7, y: 0),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    // --- Edge light glow at the edges of the icon ---
    let glowColor = NSColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 1.0)
    let frameThickness = s * 0.07
    let innerRect = iconRect.insetBy(dx: frameThickness, dy: frameThickness)
    let innerRadius = max(0, iconRadius - frameThickness)

    // Outer glow bleeding inward
    let glowLayers = 25
    for i in 0..<glowLayers {
        let t = CGFloat(i) / CGFloat(glowLayers)
        let shrink = frameThickness * t
        let alpha = 0.06 * (1.0 - t)

        let glowOuter = iconRect.insetBy(dx: shrink * 0.3, dy: shrink * 0.3)
        let glowInner = iconRect.insetBy(dx: frameThickness + shrink * 0.5, dy: frameThickness + shrink * 0.5)
        if glowInner.width <= 0 || glowInner.height <= 0 { continue }

        let outerP = CGPath(roundedRect: glowOuter,
                            cornerWidth: max(0, iconRadius - shrink * 0.3),
                            cornerHeight: max(0, iconRadius - shrink * 0.3), transform: nil)
        let innerP = CGPath(roundedRect: glowInner,
                            cornerWidth: max(0, innerRadius - shrink * 0.5),
                            cornerHeight: max(0, innerRadius - shrink * 0.5), transform: nil)

        let framePath = CGMutablePath()
        framePath.addPath(outerP)
        framePath.addPath(innerP)

        context.setFillColor(glowColor.withAlphaComponent(CGFloat(alpha)).cgColor)
        context.addPath(framePath)
        context.fillPath(using: .evenOdd)
    }

    // Solid edge light frame at the border
    let solidOuter = iconRect
    let solidInner = innerRect
    let outerP = CGPath(roundedRect: solidOuter, cornerWidth: iconRadius, cornerHeight: iconRadius, transform: nil)
    let innerP = CGPath(roundedRect: solidInner, cornerWidth: innerRadius, cornerHeight: innerRadius, transform: nil)

    let solidFrame = CGMutablePath()
    solidFrame.addPath(outerP)
    solidFrame.addPath(innerP)

    context.saveGState()
    context.addPath(solidFrame)
    context.clip(using: .evenOdd)

    let gradColors = [
        NSColor.white.withAlphaComponent(0.95).cgColor,
        NSColor(red: 1.0, green: 0.93, blue: 0.78, alpha: 0.9).cgColor,
        NSColor(red: 1.0, green: 0.88, blue: 0.65, alpha: 0.95).cgColor,
        NSColor(red: 1.0, green: 0.93, blue: 0.78, alpha: 0.9).cgColor,
        NSColor.white.withAlphaComponent(0.95).cgColor,
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.3, 0.5, 0.7, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: locations) {
        context.drawLinearGradient(gradient,
                                  start: CGPoint(x: iconRect.minX, y: iconRect.maxY),
                                  end: CGPoint(x: iconRect.maxX, y: iconRect.minY),
                                  options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    context.restoreGState()

    // Bloom — additive glow on the frame
    context.saveGState()
    context.setBlendMode(.plusLighter)
    for i in 0..<12 {
        let t = CGFloat(i) / 12.0
        let expand = s * 0.03 * (1.0 - t)
        let alpha = 0.1 * (1.0 - t)

        let bloomInner = innerRect.insetBy(dx: expand, dy: expand)
        if bloomInner.width <= 0 || bloomInner.height <= 0 { continue }

        let bOuterP = CGPath(roundedRect: iconRect, cornerWidth: iconRadius, cornerHeight: iconRadius, transform: nil)
        let bInnerP = CGPath(roundedRect: bloomInner,
                             cornerWidth: max(0, innerRadius - expand),
                             cornerHeight: max(0, innerRadius - expand), transform: nil)

        let bloomPath = CGMutablePath()
        bloomPath.addPath(bOuterP)
        bloomPath.addPath(bInnerP)

        context.setFillColor(NSColor.white.withAlphaComponent(CGFloat(alpha)).cgColor)
        context.addPath(bloomPath)
        context.fillPath(using: .evenOdd)
    }
    context.restoreGState()

    // --- Light-themed application windows centered in the glow ring ---
    let screenArea = innerRect.insetBy(dx: s * 0.03, dy: s * 0.03)
    let winRadius = s * 0.02
    let titleBarH = s * 0.04

    // Calculate centered window group
    let groupW = screenArea.width * 0.78
    let groupH = screenArea.height * 0.72
    let groupX = screenArea.midX - groupW * 0.5
    let groupY = screenArea.midY - groupH * 0.5

    // Back window (offset behind)
    let backWin = CGRect(x: groupX - s * 0.03, y: groupY + s * 0.03,
                         width: groupW, height: groupH)
    let backWinPath = CGPath(roundedRect: backWin, cornerWidth: winRadius, cornerHeight: winRadius, transform: nil)

    // Shadow for back window
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.005), blur: s * 0.015,
                      color: NSColor(white: 0, alpha: 0.4).cgColor)
    context.setFillColor(NSColor(white: 0.92, alpha: 1.0).cgColor)
    context.addPath(backWinPath)
    context.fillPath()
    context.restoreGState()

    // Back window title bar
    let backTitleBar = CGRect(x: backWin.minX, y: backWin.maxY - titleBarH,
                              width: backWin.width, height: titleBarH)
    context.saveGState()
    let backTitlePath = CGMutablePath()
    backTitlePath.move(to: CGPoint(x: backTitleBar.minX + winRadius, y: backTitleBar.maxY))
    backTitlePath.addArc(tangent1End: CGPoint(x: backTitleBar.minX, y: backTitleBar.maxY),
                         tangent2End: CGPoint(x: backTitleBar.minX, y: backTitleBar.minY), radius: winRadius)
    backTitlePath.addLine(to: CGPoint(x: backTitleBar.minX, y: backTitleBar.minY))
    backTitlePath.addLine(to: CGPoint(x: backTitleBar.maxX, y: backTitleBar.minY))
    backTitlePath.addLine(to: CGPoint(x: backTitleBar.maxX, y: backTitleBar.maxY - winRadius))
    backTitlePath.addArc(tangent1End: CGPoint(x: backTitleBar.maxX, y: backTitleBar.maxY),
                         tangent2End: CGPoint(x: backTitleBar.maxX - winRadius, y: backTitleBar.maxY), radius: winRadius)
    backTitlePath.closeSubpath()
    context.addPath(backTitlePath)
    context.setFillColor(NSColor(red: 0.48, green: 0.55, blue: 0.67, alpha: 1.0).cgColor)
    context.fillPath()
    context.restoreGState()

    // Content lines in back window
    context.setFillColor(NSColor(white: 0.78, alpha: 1.0).cgColor)
    for i in 0..<3 {
        let ly = backWin.minY + s * 0.02 + CGFloat(i) * s * 0.025
        let lw = backWin.width * (i == 0 ? 0.5 : i == 2 ? 0.3 : 0.4) - s * 0.04
        context.fill(CGRect(x: backWin.minX + s * 0.02, y: ly, width: lw, height: s * 0.012))
    }

    // Front window (centered, overlapping)
    let frontWin = CGRect(x: groupX + s * 0.03, y: groupY - s * 0.03,
                          width: groupW, height: groupH)
    let frontWinPath = CGPath(roundedRect: frontWin, cornerWidth: winRadius, cornerHeight: winRadius, transform: nil)

    // Shadow for front window
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.008), blur: s * 0.025,
                      color: NSColor(white: 0, alpha: 0.5).cgColor)
    context.setFillColor(NSColor(white: 0.96, alpha: 1.0).cgColor)
    context.addPath(frontWinPath)
    context.fillPath()
    context.restoreGState()

    // Front window title bar
    let frontTitleBar = CGRect(x: frontWin.minX, y: frontWin.maxY - titleBarH,
                               width: frontWin.width, height: titleBarH)
    context.saveGState()
    let frontTitlePath = CGMutablePath()
    frontTitlePath.move(to: CGPoint(x: frontTitleBar.minX + winRadius, y: frontTitleBar.maxY))
    frontTitlePath.addArc(tangent1End: CGPoint(x: frontTitleBar.minX, y: frontTitleBar.maxY),
                          tangent2End: CGPoint(x: frontTitleBar.minX, y: frontTitleBar.minY), radius: winRadius)
    frontTitlePath.addLine(to: CGPoint(x: frontTitleBar.minX, y: frontTitleBar.minY))
    frontTitlePath.addLine(to: CGPoint(x: frontTitleBar.maxX, y: frontTitleBar.minY))
    frontTitlePath.addLine(to: CGPoint(x: frontTitleBar.maxX, y: frontTitleBar.maxY - winRadius))
    frontTitlePath.addArc(tangent1End: CGPoint(x: frontTitleBar.maxX, y: frontTitleBar.maxY),
                          tangent2End: CGPoint(x: frontTitleBar.maxX - winRadius, y: frontTitleBar.maxY), radius: winRadius)
    frontTitlePath.closeSubpath()
    context.addPath(frontTitlePath)
    context.setFillColor(NSColor(red: 0.53, green: 0.60, blue: 0.72, alpha: 1.0).cgColor)
    context.fillPath()
    context.restoreGState()

    // Traffic light dots on front window
    let dotRadius = s * 0.008
    let dotY = frontTitleBar.midY
    let dotStartX = frontTitleBar.minX + s * 0.025
    let dotSpacing = s * 0.02
    let dotColors: [NSColor] = [
        NSColor(red: 1.0, green: 0.38, blue: 0.35, alpha: 0.9),
        NSColor(red: 1.0, green: 0.78, blue: 0.25, alpha: 0.9),
        NSColor(red: 0.30, green: 0.85, blue: 0.40, alpha: 0.9),
    ]
    for (j, color) in dotColors.enumerated() {
        let cx = dotStartX + CGFloat(j) * dotSpacing
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: cx - dotRadius, y: dotY - dotRadius,
                                       width: dotRadius * 2, height: dotRadius * 2))
    }

    // Content lines in front window
    context.setFillColor(NSColor(white: 0.82, alpha: 1.0).cgColor)
    for i in 0..<4 {
        let ly = frontWin.minY + s * 0.02 + CGFloat(i) * s * 0.025
        let lw = frontWin.width * (i == 0 ? 0.6 : i == 3 ? 0.35 : 0.5) - s * 0.04
        context.fill(CGRect(x: frontWin.minX + s * 0.02, y: ly, width: lw, height: s * 0.012))
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, pixelSize: Int, to path: String) {
    // Create a bitmap at exact pixel dimensions (no Retina scaling)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("Failed to create bitmap for \(path)")
        return
    }
    bitmap.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created \(path) (\(pixelSize)x\(pixelSize)px)")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

let outputDir = "MacEdgeLight/Assets.xcassets/AppIcon.appiconset"

// Generate all required sizes
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, filename) in sizes {
    let icon = generateIcon(size: size)
    savePNG(icon, pixelSize: size, to: "\(outputDir)/\(filename)")
}

print("Done! Icon files generated.")
