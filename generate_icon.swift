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
    let iconRadius = s * 0.185  // macOS icon corner radius

    // Dark background with rounded rect
    let bgPath = CGPath(roundedRect: bounds.insetBy(dx: s * 0.02, dy: s * 0.02),
                        cornerWidth: iconRadius, cornerHeight: iconRadius, transform: nil)
    context.addPath(bgPath)
    context.setFillColor(NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0).cgColor)
    context.fillPath()

    // Draw a "monitor" shape in the center
    let monitorInset = s * 0.18
    let monitorRect = bounds.insetBy(dx: monitorInset, dy: monitorInset + s * 0.02)
    let monitorRadius = s * 0.04
    let monitorPath = CGPath(roundedRect: monitorRect,
                             cornerWidth: monitorRadius, cornerHeight: monitorRadius, transform: nil)

    // Dark screen fill
    context.addPath(monitorPath)
    context.setFillColor(NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0).cgColor)
    context.fillPath()

    // Edge light glow around the monitor - multiple passes for soft glow
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // Warm white-to-amber color for the glow
    let glowColor = NSColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 1.0)

    // Outer glow (soft, wide)
    let glowLayers = 20
    for i in 0..<glowLayers {
        let t = CGFloat(i) / CGFloat(glowLayers)
        let expand = s * 0.06 * (1.0 - t)
        let alpha = 0.04 * (1.0 - t)

        let glowRect = monitorRect.insetBy(dx: -expand, dy: -expand)
        let innerGlowRect = monitorRect.insetBy(dx: expand * 0.5, dy: expand * 0.5)

        let outerPath = CGPath(roundedRect: glowRect,
                               cornerWidth: monitorRadius + expand,
                               cornerHeight: monitorRadius + expand, transform: nil)
        let innerPath = CGPath(roundedRect: innerGlowRect.width > 0 ? innerGlowRect : monitorRect,
                               cornerWidth: max(0, monitorRadius - expand * 0.5),
                               cornerHeight: max(0, monitorRadius - expand * 0.5), transform: nil)

        let framePath = CGMutablePath()
        framePath.addPath(outerPath)
        framePath.addPath(innerPath)

        context.setFillColor(glowColor.withAlphaComponent(CGFloat(alpha)).cgColor)
        context.addPath(framePath)
        context.fillPath(using: .evenOdd)
    }

    // Solid edge light frame
    let frameWidth = s * 0.035
    let outerFrameRect = monitorRect.insetBy(dx: -frameWidth * 0.5, dy: -frameWidth * 0.5)
    let innerFrameRect = monitorRect.insetBy(dx: frameWidth * 0.5, dy: frameWidth * 0.5)

    let outerFramePath = CGPath(roundedRect: outerFrameRect,
                                cornerWidth: monitorRadius + frameWidth * 0.5,
                                cornerHeight: monitorRadius + frameWidth * 0.5, transform: nil)
    let innerFramePath = CGPath(roundedRect: innerFrameRect,
                                cornerWidth: max(0, monitorRadius - frameWidth * 0.5),
                                cornerHeight: max(0, monitorRadius - frameWidth * 0.5), transform: nil)

    // Clip to frame shape and draw gradient
    let solidFrame = CGMutablePath()
    solidFrame.addPath(outerFramePath)
    solidFrame.addPath(innerFramePath)

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
                                  start: CGPoint(x: outerFrameRect.minX, y: outerFrameRect.maxY),
                                  end: CGPoint(x: outerFrameRect.maxX, y: outerFrameRect.minY),
                                  options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    context.restoreGState()

    // Bloom effect - additive glow on the frame
    context.saveGState()
    context.setBlendMode(.plusLighter)

    for i in 0..<10 {
        let t = CGFloat(i) / 10.0
        let expand = s * 0.02 * (1.0 - t)
        let alpha = 0.08 * (1.0 - t)

        let bloomOuter = outerFrameRect.insetBy(dx: -expand, dy: -expand)
        let bloomInner = innerFrameRect.insetBy(dx: expand, dy: expand)

        let outerP = CGPath(roundedRect: bloomOuter,
                            cornerWidth: monitorRadius + frameWidth * 0.5 + expand,
                            cornerHeight: monitorRadius + frameWidth * 0.5 + expand, transform: nil)
        let innerP = CGPath(roundedRect: bloomInner.width > 0 ? bloomInner : innerFrameRect,
                            cornerWidth: max(0, monitorRadius - frameWidth * 0.5 - expand),
                            cornerHeight: max(0, monitorRadius - frameWidth * 0.5 - expand), transform: nil)

        let bloomPath = CGMutablePath()
        bloomPath.addPath(outerP)
        bloomPath.addPath(innerP)

        context.setFillColor(NSColor.white.withAlphaComponent(CGFloat(alpha)).cgColor)
        context.addPath(bloomPath)
        context.fillPath(using: .evenOdd)
    }
    context.restoreGState()

    // Subtle reflection on the "screen" - a faint gradient
    context.saveGState()
    context.addPath(monitorPath)
    context.clip()

    let reflectionColors = [
        NSColor(white: 1.0, alpha: 0.04).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor,
    ] as CFArray
    let reflectionLocations: [CGFloat] = [0.0, 1.0]
    if let reflectionGrad = CGGradient(colorsSpace: colorSpace, colors: reflectionColors, locations: reflectionLocations) {
        context.drawLinearGradient(reflectionGrad,
                                  start: CGPoint(x: monitorRect.midX, y: monitorRect.maxY),
                                  end: CGPoint(x: monitorRect.midX, y: monitorRect.midY),
                                  options: [])
    }
    context.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created \(path)")
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
    savePNG(icon, to: "\(outputDir)/\(filename)")
}

print("Done! Icon files generated.")
