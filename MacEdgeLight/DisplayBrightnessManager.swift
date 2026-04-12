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
    private var displayLink: CVDisplayLink?
    private let renderLock = NSLock()
    private var savedGammaTables: [CGDirectDisplayID: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])] = [:]

    /// Maximum EDR headroom requested from macOS via the invisible Metal overlay.
    /// The overlay is not visible — it only signals macOS to grant headroom.
    private let maxHeadroomCap: Double = 16.0

    /// Linear gamma scale factor — maps the 0-1 range into 0-gammaScale,
    /// stretching values into the EDR range. Preserves relative contrast
    /// (unlike power curves which compress midtones).
    private let gammaScale: Float = 1.45

    /// Never exceed this fraction of actual current headroom when applying
    /// gamma boost. Leaves margin for sudden drops (thermal throttling,
    /// auto-brightness) so content doesn't clip to white.
    private let gammaHeadroomSafety: Float = 0.85

    /// Currently applied gamma scale — tracked so we only re-upload the LUT
    /// when headroom changes meaningfully.
    private var currentAppliedGammaScale: Float = 1.0
    private var lastGammaUpdate: TimeInterval = 0

    var isAvailable: Bool {
        guard metalDevice != nil else { return false }
        return NSScreen.screens.contains {
            $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0
        }
    }

    private init() {
        metalDevice = MTLCreateSystemDefaultDevice()
        commandQueue = metalDevice?.makeCommandQueue()
    }

    func toggle() {
        if isBoosted { deactivate() } else { activate() }
    }

    func restore() {
        if isBoosted { deactivate() }
    }

    /// Force every display's gamma LUT back to its ColorSync profile default.
    /// Safe to call at any time — used at launch and on wake to wipe out any
    /// leaked/dirty LUT state from prior runs or sleep cycles that would
    /// otherwise make every bright pixel clip to white.
    static func resetGammaToProfile() {
        CGDisplayRestoreColorSyncSettings()
    }

    // MARK: - Activate / Deactivate

    private func activate() {
        isChanging = true
        // Hardware backlight intentionally left alone — DisplayServices
        // always animates brightness changes over ~300-500ms, which makes
        // the toggle feel mushy. The gamma LUT + EDR headroom deliver the
        // perceptible boost and both apply within a single compositor frame.
        saveAndBoostGamma()
        createOverlays()
        startDisplayLink()
        isBoosted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.isChanging = false }
    }

    private func deactivate() {
        isChanging = true
        isBoosted = false

        // Gamma LUT revert is instant — do it first so the 1.45x scale
        // disappears within the next compositor frame.
        restoreGamma()

        // Kill EDR signaling synchronously. Previously these ran async and
        // macOS held EDR headroom for ~500ms while the display link drained,
        // which looked like a visible fade. Stopping the display link and
        // removing the Metal layers on the caller's frame means macOS sees
        // "no more EDR content" immediately and starts dropping headroom.
        stopDisplayLink()
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        metalLayers.removeAll()

        // Observer cleanup doesn't affect visible state — defer.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let obs = self.screenObserver {
                NotificationCenter.default.removeObserver(obs)
                self.screenObserver = nil
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.isChanging = false }
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

            savedGammaTables[displayID] = (
                red: Array(red[0..<Int(actualCount)]),
                green: Array(green[0..<Int(actualCount)]),
                blue: Array(blue[0..<Int(actualCount)]),
            )
        }

        // Start at a safe scale based on the current available headroom,
        // then let adjustGammaForHeadroom() track live changes.
        let initialScale = safeGammaScale()
        applyGammaScale(initialScale)
        currentAppliedGammaScale = initialScale
    }

    /// Re-uploads the gamma LUT with the given linear scale applied on top of
    /// the saved originals. Blacks stay at 0, everything else scales linearly.
    private func applyGammaScale(_ scale: Float) {
        for (displayID, tables) in savedGammaTables {
            let count = tables.red.count
            var boostedRed = [CGGammaValue](repeating: 0, count: count)
            var boostedGreen = [CGGammaValue](repeating: 0, count: count)
            var boostedBlue = [CGGammaValue](repeating: 0, count: count)
            for i in 0..<count {
                boostedRed[i] = tables.red[i] * scale
                boostedGreen[i] = tables.green[i] * scale
                boostedBlue[i] = tables.blue[i] * scale
            }
            CGSetDisplayTransferByTable(displayID, UInt32(count), boostedRed, boostedGreen, boostedBlue)
        }
    }

    /// Clamp the desired gamma scale to what the display can currently
    /// sustain, using the minimum live headroom across EDR screens with a
    /// safety margin. Never returns below 1.0 (neutral).
    private func safeGammaScale() -> Float {
        let headrooms = NSScreen.screens
            .filter { $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0 }
            .map { Float($0.maximumExtendedDynamicRangeColorComponentValue) }
        return Self.safeGammaScale(
            desired: gammaScale,
            liveHeadrooms: headrooms,
            safety: gammaHeadroomSafety
        )
    }

    /// Pure function version, exposed for tests. Given the desired max gamma
    /// scale, a list of live EDR headroom values (one per EDR-capable screen),
    /// and a safety fraction, returns the scale that should be applied.
    static func safeGammaScale(desired: Float, liveHeadrooms: [Float], safety: Float) -> Float {
        guard let minHeadroom = liveHeadrooms.min() else { return 1.0 }
        let headroomCeiling = max(1.0, minHeadroom * safety)
        return min(desired, headroomCeiling)
    }

    /// Called from the display link every frame; throttled to ~2 Hz. When
    /// available headroom drifts (thermal throttling, ambient light change,
    /// True Tone), re-upload the gamma LUT so content doesn't clip.
    private func adjustGammaForHeadroom() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastGammaUpdate > 0.5 else { return }

        let target = safeGammaScale()
        guard abs(target - currentAppliedGammaScale) > 0.02 else { return }

        lastGammaUpdate = now
        currentAppliedGammaScale = target
        DispatchQueue.main.async { [weak self] in
            self?.applyGammaScale(target)
        }
    }

    private func restoreGamma() {
        for (displayID, tables) in savedGammaTables {
            let count = tables.red.count
            CGSetDisplayTransferByTable(displayID, UInt32(count), tables.red, tables.green, tables.blue)
        }
        savedGammaTables.removeAll()
        currentAppliedGammaScale = 1.0
        lastGammaUpdate = 0
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
        adjustGammaForHeadroom()
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
