import Cocoa
import Metal
import QuartzCore

/// Boosts display brightness into XDR extended range using a full-screen Metal
/// overlay with multiply compositing. The overlay renders at the maximum current
/// EDR headroom, dynamically queried every frame, so all screen content is
/// boosted to the brightest the display can produce. Hardware backlight is also
/// set to max via DisplayServices.
///
/// The Metal layer must be re-rendered periodically — macOS dynamically manages
/// EDR headroom and decays extended range if no new frames are presented.
/// Headroom is queried on every frame to prevent white-screen clipping when
/// the available range changes (brightness adjustment, True Tone, sleep/wake).
class DisplayBrightnessManager {
    static let shared = DisplayBrightnessManager()

    private(set) var isBoosted = false
    /// True while we're changing brightness, so screen-change observers can ignore the notification
    private(set) var isChanging = false

    private var overlayWindows: [NSWindow] = []
    private var metalLayers: [(CAMetalLayer, NSScreen)] = []
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var screenObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var displayLink: CVDisplayLink?
    private let renderLock = NSLock()
    private var savedBrightness: [CGDirectDisplayID: Float] = [:]
    private var savedGammaTables: [CGDirectDisplayID: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])] = [:]

    /// Maximum EDR headroom requested from macOS via the invisible Metal overlay.
    /// The overlay is not visible — it only signals macOS to grant headroom.
    private let maxHeadroomCap: Double = 16.0

    /// Linear gamma scale factor — maps the 0-1 range into 0-gammaScale,
    /// stretching values into the EDR range. Preserves relative contrast
    /// (unlike power curves which compress midtones).
    private let gammaScale: Float = 1.45

    // DisplayServices function pointers
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private let getBrightness: GetBrightnessFn?
    private let setBrightness: SetBrightnessFn?

    var isAvailable: Bool {
        guard metalDevice != nil else { return false }
        return NSScreen.screens.contains {
            $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0
        }
    }

    private init() {
        metalDevice = MTLCreateSystemDefaultDevice()
        commandQueue = metalDevice?.makeCommandQueue()

        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        if let handle = handle,
           let getPtr = dlsym(handle, "DisplayServicesGetBrightness"),
           let setPtr = dlsym(handle, "DisplayServicesSetBrightness") {
            getBrightness = unsafeBitCast(getPtr, to: GetBrightnessFn.self)
            setBrightness = unsafeBitCast(setPtr, to: SetBrightnessFn.self)
        } else {
            getBrightness = nil
            setBrightness = nil
        }
    }

    func toggle() {
        if isBoosted { deactivate() } else { activate() }
    }

    func restore() {
        if isBoosted { deactivate() }
    }

    // MARK: - Activate / Deactivate

    private func activate() {
        isChanging = true
        saveCurrentBrightness()
        setMaxBrightness()
        saveAndBoostGamma()
        createOverlays()
        startDisplayLink()
        isBoosted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.isChanging = false }
    }

    private func deactivate() {
        isChanging = true
        stopDisplayLink()
        if let obs = screenObserver {
            NotificationCenter.default.removeObserver(obs)
            screenObserver = nil
        }
        if let obs = wakeObserver {
            NotificationCenter.default.removeObserver(obs)
            wakeObserver = nil
        }
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        metalLayers.removeAll()
        restoreGamma()
        restoreBrightness()
        isBoosted = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.isChanging = false }
    }

    // MARK: - Hardware brightness

    private func saveCurrentBrightness() {
        savedBrightness.removeAll()
        guard let getter = getBrightness else { return }
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            var current: Float = 0
            if getter(displayID, &current) == 0 {
                savedBrightness[displayID] = current
            }
        }
    }

    private func setMaxBrightness() {
        guard let setter = setBrightness else { return }
        for (displayID, _) in savedBrightness {
            _ = setter(displayID, 1.0)
        }
    }

    private func restoreBrightness() {
        guard let setter = setBrightness else { return }
        for (displayID, brightness) in savedBrightness {
            _ = setter(displayID, brightness)
        }
        savedBrightness.removeAll()
    }

    // MARK: - Gamma table boost

    private func saveAndBoostGamma() {
        savedGammaTables.removeAll()
        let sampleCount: UInt32 = 256

        for screen in NSScreen.screens {
            let displayID = screen.displayID
            var red = [CGGammaValue](repeating: 0, count: Int(sampleCount))
            var green = [CGGammaValue](repeating: 0, count: Int(sampleCount))
            var blue = [CGGammaValue](repeating: 0, count: Int(sampleCount))
            var actualCount: UInt32 = 0

            guard CGGetDisplayTransferByTable(displayID, sampleCount, &red, &green, &blue, &actualCount) == .success,
                  actualCount > 1 else { continue }

            // Save original tables
            savedGammaTables[displayID] = (
                red: Array(red[0..<Int(actualCount)]),
                green: Array(green[0..<Int(actualCount)]),
                blue: Array(blue[0..<Int(actualCount)]),
            )

            // Linear scale: maps 0-1 into 0-gammaScale, pushing values into
            // the EDR range. Preserves relative contrast between tones —
            // blacks stay black, everything else gets proportionally brighter.
            let count = Int(actualCount)
            var boostedRed = [CGGammaValue](repeating: 0, count: count)
            var boostedGreen = [CGGammaValue](repeating: 0, count: count)
            var boostedBlue = [CGGammaValue](repeating: 0, count: count)

            for i in 0..<count {
                boostedRed[i] = red[i] * gammaScale
                boostedGreen[i] = green[i] * gammaScale
                boostedBlue[i] = blue[i] * gammaScale
            }

            CGSetDisplayTransferByTable(displayID, UInt32(count), boostedRed, boostedGreen, boostedBlue)
        }
    }

    private func restoreGamma() {
        for (displayID, tables) in savedGammaTables {
            let count = tables.red.count
            CGSetDisplayTransferByTable(displayID, UInt32(count), tables.red, tables.green, tables.blue)
        }
        savedGammaTables.removeAll()
    }

    // MARK: - Display link

    private func startDisplayLink() {
        stopDisplayLink()
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link = link else { return }
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userInfo) -> CVReturn in
            let mgr = Unmanaged<DisplayBrightnessManager>.fromOpaque(userInfo!).takeUnretainedValue()
            mgr.renderAllLayers()
            return kCVReturnSuccess
        }, selfPtr)
        CVDisplayLinkStart(link)
        displayLink = link
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    /// Returns the headroom value currently being applied to the overlay for a given screen.
    /// Capped to the current headroom macOS has actually granted (not potential).
    func appliedHeadroom(for screen: NSScreen) -> Double {
        return min(screen.maximumExtendedDynamicRangeColorComponentValue, maxHeadroomCap)
    }

    // MARK: - EDR overlay


    private func createOverlays() {
        guard let device = metalDevice, let queue = commandQueue else { return }

        metalLayers.removeAll()

        for screen in NSScreen.screens {
            let maxEDR = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
            guard maxEDR > 1.0 else { continue }

            // Full-screen EDR overlay using sourceOver compositing. Renders
            // EDR white behind all content to boost the display's actual light
            // output into XDR range without multiplying screen content.
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none

            let rootLayer = CALayer()
            rootLayer.isOpaque = false
            rootLayer.backgroundColor = CGColor.clear
            // No compositingFilter — default sourceOver compositing

            let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.layer = rootLayer
            view.wantsLayer = true
            window.contentView = view

            let metalLayer = CAMetalLayer()
            metalLayer.device = device
            metalLayer.pixelFormat = .rgba16Float
            metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            metalLayer.wantsExtendedDynamicRangeContent = true
            metalLayer.isOpaque = false
            metalLayer.contentsScale = screen.backingScaleFactor
            metalLayer.actions = [
                "contents": NSNull(),
                "bounds": NSNull(),
                "position": NSNull(),
            ]
            metalLayer.frame = CGRect(origin: .zero, size: screen.frame.size)
            metalLayer.drawableSize = CGSize(
                width: screen.frame.width * screen.backingScaleFactor,
                height: screen.frame.height * screen.backingScaleFactor
            )
            rootLayer.addSublayer(metalLayer)

            let headroom = min(screen.maximumExtendedDynamicRangeColorComponentValue, maxHeadroomCap)
            renderFrame(metalLayer: metalLayer, brightness: headroom, queue: queue)
            metalLayers.append((metalLayer, screen))
            window.orderFront(nil)
            overlayWindows.append(window)
        }

        // Re-create overlays when screen configuration changes (e.g. display
        // plugged in/out, resolution change) so geometry and EDR values stay correct.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.rebuildOverlays()
        }

        // After sleep/wake, headroom may be stale — rebuild overlays so the
        // display link picks up fresh values.
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Short delay: headroom takes a moment to stabilize after wake
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.rebuildOverlays()
            }
        }
    }

    private var isRebuilding = false

    private func rebuildOverlays() {
        guard !isChanging, !isRebuilding else { return }
        isRebuilding = true
        stopDisplayLink()
        if let obs = screenObserver {
            NotificationCenter.default.removeObserver(obs)
            screenObserver = nil
        }
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        createOverlays()
        startDisplayLink()
        isRebuilding = false
    }

    private func renderAllLayers() {
        guard renderLock.try() else { return }  // Skip frame if previous render still in progress
        defer { renderLock.unlock() }
        guard let queue = commandQueue else { return }
        let layers = metalLayers  // Snapshot to avoid mutation during iteration
        for (layer, screen) in layers {
            // Use the maximum potential headroom directly so brightness jumps
            // to full immediately instead of ramping up as macOS warms the
            // dynamic headroom value.
            let headroom = min(screen.maximumExtendedDynamicRangeColorComponentValue, maxHeadroomCap)
            renderFrame(metalLayer: layer, brightness: headroom, queue: queue)
        }
    }

    private func renderFrame(metalLayer: CAMetalLayer, brightness: Double, queue: MTLCommandQueue) {
        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = queue.makeCommandBuffer() else { return }

        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = drawable.texture
        desc.colorAttachments[0].loadAction = .clear
        desc.colorAttachments[0].storeAction = .store
        // Render EDR values with alpha=0: invisible to the user but signals
        // macOS to grant extended dynamic range headroom for this display.
        desc.colorAttachments[0].clearColor = MTLClearColor(
            red: brightness, green: brightness, blue: brightness, alpha: 0.0
        )

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) else { return }
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
    }
}
