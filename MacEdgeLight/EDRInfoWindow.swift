import Cocoa

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

        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 340, height: 0),
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

        let field = NSTextField(wrappingLabelWithString: "")
        field.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
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

            // Effective brightness: headroom * backlight gives a relative measure
            // of where we are vs the display's peak capability
            if hwBrightness >= 0 && current > 0 {
                let effectivePeak = Double(hwBrightness) * current
                let maxPossiblePeak = Double(1.0) * potential
                let pctOfPeak = maxPossiblePeak > 0 ? (effectivePeak / maxPossiblePeak) * 100 : 0
                lines.append("  Effective vs peak:   \(String(format: "%.1f%%", pctOfPeak))")
            }

            if i < NSScreen.screens.count - 1 {
                lines.append("")
            }
        }

        textField.stringValue = lines.joined(separator: "\n")
    }
}
