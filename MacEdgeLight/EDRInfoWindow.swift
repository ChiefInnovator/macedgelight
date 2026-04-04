import Cocoa
import CoreGraphics

private extension CGColorSpaceModel {
    var debugName: String {
        switch self {
        case .unknown: return "unknown"
        case .monochrome: return "monochrome"
        case .rgb: return "RGB"
        case .cmyk: return "CMYK"
        case .lab: return "Lab"
        case .deviceN: return "DeviceN"
        case .indexed: return "indexed"
        case .pattern: return "pattern"
        case .XYZ: return "XYZ"
        @unknown default: return "model(\(rawValue))"
        }
    }
}

class EDRInfoWindow: NSPanel {
    private var updateTimer: Timer?
    private var textField: NSTextField!

    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private let getBrightness: GetBrightnessFn?

    static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        return result == 0 && (info.kp_proc.p_flag & P_TRACED) != 0
    }

    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        if let handle = handle, let getPtr = dlsym(handle, "DisplayServicesGetBrightness") {
            getBrightness = unsafeBitCast(getPtr, to: GetBrightnessFn.self)
        } else {
            getBrightness = nil
        }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let windowWidth: CGFloat = 520
        let windowHeight: CGFloat = 400
        let origin = NSPoint(
            x: screenFrame.minX + 20,
            y: screenFrame.maxY - windowHeight - 20
        )

        super.init(
            contentRect: NSRect(origin: origin, size: NSSize(width: windowWidth, height: windowHeight)),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.title = "EDR Info"
        self.isOpaque = false
        self.backgroundColor = NSColor(white: 0.08, alpha: 0.92)
        self.hasShadow = true
        self.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .visible

        // Keep the close button always visible (not just on hover)
        self.standardWindowButton(.closeButton)?.alphaValue = 1.0
        self.standardWindowButton(.closeButton)?.needsDisplay = true

        let field = NSTextField(wrappingLabelWithString: "")
        field.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .medium)
        field.textColor = .white
        field.backgroundColor = .clear
        field.isBezeled = false
        field.isEditable = false
        field.translatesAutoresizingMaskIntoConstraints = false
        textField = field

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(field)

        self.contentView = container

        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])

        // Copy icon button in titlebar
        let copyButton = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy to Clipboard")
        copyButton.bezelStyle = .rounded
        copyButton.isBordered = false
        copyButton.contentTintColor = .white
        copyButton.target = self
        copyButton.action = #selector(copyToClipboard)
        copyButton.toolTip = "Copy to Clipboard"
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = copyButton
        accessory.layoutAttribute = .trailing
        self.addTitlebarAccessoryViewController(accessory)
    }

    func startUpdating() {
        refresh()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.current.add(timer, forMode: .common)
        updateTimer = timer
    }

    func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    override func close() {
        stopUpdating()
        super.close()
    }

    @objc private func copyToClipboard() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let header = "MacEdgeLight EDR Diagnostics — \(timestamp)"
        let separator = String(repeating: "─", count: header.count)
        let content = "\(header)\n\(separator)\n\(textField.stringValue)\n"

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    /// Measures how far the display gamma table deviates from identity (linear).
    /// Returns average absolute deviation per channel. Values near 0 = unmodified.
    private static func gammaDeviation(for displayID: CGDirectDisplayID) -> (r: Double, g: Double, b: Double)? {
        let sampleCount: UInt32 = 256
        var redTable = [CGGammaValue](repeating: 0, count: Int(sampleCount))
        var greenTable = [CGGammaValue](repeating: 0, count: Int(sampleCount))
        var blueTable = [CGGammaValue](repeating: 0, count: Int(sampleCount))
        var actualCount: UInt32 = 0

        let err = CGGetDisplayTransferByTable(displayID, sampleCount, &redTable, &greenTable, &blueTable, &actualCount)
        guard err == .success, actualCount > 1 else { return nil }

        var rDev = 0.0, gDev = 0.0, bDev = 0.0
        for i in 0..<Int(actualCount) {
            let expected = Float(i) / Float(actualCount - 1)
            rDev += Double(abs(redTable[i] - expected))
            gDev += Double(abs(greenTable[i] - expected))
            bDev += Double(abs(blueTable[i] - expected))
        }
        let n = Double(actualCount)
        return (rDev / n, gDev / n, bDev / n)
    }

    private func refresh() {
        var lines: [String] = []
        let boosted = DisplayBrightnessManager.shared.isBoosted

        lines.append("EDR Boost: \(boosted ? "ON" : "OFF")")
        lines.append("")

        for (i, screen) in NSScreen.screens.enumerated() {
            let name = screen.localizedName
            let displayID = screen.displayID
            let current = screen.maximumExtendedDynamicRangeColorComponentValue
            let potential = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
            let reference = screen.maximumReferenceExtendedDynamicRangeColorComponentValue

            // Hardware backlight level (0.0–1.0)
            var hwBrightness: Float = -1
            if let getter = getBrightness {
                _ = getter(displayID, &hwBrightness)
            }

            lines.append("Screen \(i): \(name)")
            if hwBrightness >= 0 {
                lines.append("  Backlight:           \(String(format: "%.1f%%", hwBrightness * 100))")
            }
            lines.append("  Current headroom:    \(String(format: "%.3f", current))x")
            lines.append("  Potential headroom:  \(String(format: "%.3f", potential))x")
            lines.append("  Reference headroom:  \(String(format: "%.3f", reference))x")
            lines.append("  EDR capable:         \(potential > 1.0 ? "YES" : "NO")")

            if boosted {
                let applied = DisplayBrightnessManager.shared.appliedHeadroom(for: screen)
                lines.append("  Applied multiply:    \(String(format: "%.3f", applied))x")
            } else {
                lines.append("  Applied multiply:    n/a")
            }

            // Effective brightness: headroom * backlight gives a relative measure
            // of where we are vs the display's peak capability
            if hwBrightness >= 0 && current > 0 {
                let effectivePeak = Double(hwBrightness) * current
                let maxPossiblePeak = Double(1.0) * potential
                let pctOfPeak = maxPossiblePeak > 0 ? (effectivePeak / maxPossiblePeak) * 100 : 0
                lines.append("  Effective vs peak:   \(String(format: "%.1f%%", pctOfPeak))")
            }

            // External EDR activity: if current > 1.0 while our boost is off,
            // another app is presenting EDR content
            if !boosted && current > 1.0 {
                lines.append("  ⚠ External EDR active (current > 1.0)")
            }

            // Gamma table — detect if something (Night Shift, f.lux, etc.)
            // has modified the display transfer curves from identity
            let gammaInfo = Self.gammaDeviation(for: displayID)
            if let info = gammaInfo {
                lines.append("  Gamma deviation:     R\(String(format: "%.3f", info.r)) G\(String(format: "%.3f", info.g)) B\(String(format: "%.3f", info.b))")
                if info.r > 0.02 || info.g > 0.02 || info.b > 0.02 {
                    if boosted {
                        lines.append("  ℹ Gamma modified (ours)")
                    } else {
                        lines.append("  ⚠ Gamma modified (Night Shift / f.lux?)")
                    }
                }
            }

            // Active color space
            let colorSpace = CGDisplayCopyColorSpace(displayID)
            let csName: String
            if let name = colorSpace.name {
                csName = (name as String)
                    .replacingOccurrences(of: "kCGColorSpace", with: "")
                    .replacingOccurrences(of: "com.apple.cs.", with: "")
            } else if let iccData = colorSpace.copyICCData(), CFDataGetLength(iccData) > 0 {
                csName = "ICC profile (\(CFDataGetLength(iccData)) bytes)"
            } else {
                csName = colorSpace.model.debugName
            }
            lines.append("  Color space:         \(csName)")

            if i < NSScreen.screens.count - 1 {
                lines.append("")
            }
        }

        textField.stringValue = lines.joined(separator: "\n")
    }
}
