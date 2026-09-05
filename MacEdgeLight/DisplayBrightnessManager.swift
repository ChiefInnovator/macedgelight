import Cocoa
import Metal
import QuartzCore

/// Boosts display brightness using an invisible Metal EDR overlay and a fresh
/// synthetic gamma ramp. macOS still controls available EDR headroom.
/// AppKit and gamma state are owned by the main thread; the display-link thread
/// only renders the layer/brightness snapshot protected by renderLock.
final class DisplayBrightnessManager {
    static let shared = DisplayBrightnessManager()

    private(set) var isBoosted = false
    /// True while we're changing brightness, so screen-change observers can ignore the notification
    private(set) var isChanging = false

    private var overlayWindows: [NSWindow] = []
    // Every target carries its own identity and health state. Geometry stays on
    // the main thread; this dictionary is shared only under renderLock.
    private struct RenderTarget {
        let displayID: CGDirectDisplayID
        let layer: CAMetalLayer
        var headroom: Double
        var lastSubmittedAt: TimeInterval
    }
    private var renderTargets: [CGDirectDisplayID: RenderTarget] = [:]
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var displayLink: CVDisplayLink?
    private let renderLock = NSLock()
    private let frameLock = NSLock()
    private var maintenanceTimer: Timer?
    private var configuration: [DisplayConfiguration] = []
    private var gammaErrors: [CGDirectDisplayID: CGError] = [:]

    private struct DisplayConfiguration: Equatable {
        let id: CGDirectDisplayID
        let frame: CGRect
        let backingScale: CGFloat
    }

    private var currentConfiguration: [DisplayConfiguration] {
        NSScreen.screens.filter {
            $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0
        }.map {
            DisplayConfiguration(id: $0.displayID, frame: $0.frame,
                                 backingScale: $0.backingScaleFactor)
        }
    }

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

    var isAvailable: Bool {
        guard metalDevice != nil, commandQueue != nil else { return false }
        return NSScreen.screens.contains {
            $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0
        }
    }

    private init() {
        metalDevice = MTLCreateSystemDefaultDevice()
        commandQueue = metalDevice?.makeCommandQueue()
    }

    func setEnabled(_ enabled: Bool) {
        precondition(Thread.isMainThread)
        guard !isChanging, enabled != isBoosted else { return }
        if enabled {
            guard isAvailable else { return }
            activate()
        } else {
            deactivate()
        }
    }

    func restore() {
        setEnabled(false)
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
        defer { isChanging = false }
        configuration = currentConfiguration
        createOverlays()
        guard !overlayWindows.isEmpty else { return }
        isBoosted = true
        startDisplayLink()
        maintainBoost()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.maintainBoost()
        }
        RunLoop.main.add(timer, forMode: .common)
        maintenanceTimer = timer
    }

    private func deactivate() {
        isChanging = true
        defer { isChanging = false }
        isBoosted = false
        maintenanceTimer?.invalidate()
        maintenanceTimer = nil
        stopDisplayLink()
        // No queued gamma writes can run after this authoritative reset.
        Self.resetGammaToProfile()
        removeOverlays()
        configuration = []
        gammaErrors.removeAll()
    }

    private func removeOverlays() {
        for window in overlayWindows { window.orderOut(nil) }
        overlayWindows.removeAll()
        renderLock.lock()
        renderTargets.removeAll()
        renderLock.unlock()
    }

    // MARK: - Gamma table boost

    /// Reassert a fresh ramp even if the desired scale has not changed: macOS
    /// can replace the LUT without changing EDR headroom. Failed writes retry on
    /// the next maintenance tick. Never read/rescale the live transfer table.
    private func applyGammaScale(_ scale: Float, to displayID: CGDirectDisplayID) {
        let ramp = Self.buildBoostedRamp(scale: scale, count: 256)
        let result = CGSetDisplayTransferByTable(displayID, UInt32(ramp.count), ramp, ramp, ramp)
        if result != .success, gammaErrors[displayID] != result {
            NSLog("Brightness boost gamma write failed for display %u: %d; will retry", displayID, result.rawValue)
        }
        gammaErrors[displayID] = result
    }

    /// Pure function, exposed for tests. Builds a linear ramp from 0 up to
    /// `scale` across `count` samples. At scale 1.0 this is the identity ramp.
    static func buildBoostedRamp(scale: Float, count: Int) -> [CGGammaValue] {
        guard count > 1 else { return [] }
        let denom = Float(count - 1)
        return (0..<count).map { Float($0) / denom * scale }
    }

    /// Pure function version, exposed for tests. Given the desired max gamma
    /// scale, a list of live EDR headroom values (one per EDR-capable screen),
    /// and a safety fraction, returns the scale that should be applied.
    static func safeGammaScale(desired: Float, liveHeadrooms: [Float], safety: Float) -> Float {
        guard desired.isFinite, desired >= 1.0,
              safety.isFinite, safety > 0, safety <= 1,
              !liveHeadrooms.isEmpty,
              liveHeadrooms.allSatisfy({ $0.isFinite && $0 >= 1.0 }),
              let minHeadroom = liveHeadrooms.min() else { return 1.0 }
        let headroomCeiling = max(1.0, minHeadroom * safety)
        return min(desired, headroomCeiling)
    }

    /// Runs on the main run loop, independently of display-link delivery.
    /// Each display uses its own headroom so a dim external screen cannot lower
    /// the boost on another screen. Also recovers stopped/stalled renderers.
    private func maintainBoost() {
        guard isBoosted else { return }
        refreshDisplayConfiguration()
        renderLock.lock()
        let now = ProcessInfo.processInfo.systemUptime
        let stalled = renderTargets.values.contains { now - $0.lastSubmittedAt > 2.0 }
        renderLock.unlock()

        if stalled {
            rebuildOverlays()
        }
        if displayLink == nil { renderAllLayers() }

        refreshGamma()
    }

    private func refreshGamma() {
        for screen in NSScreen.screens where screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0 {
            let scale = Self.safeGammaScale(
                desired: gammaScale,
                liveHeadrooms: [Float(screen.maximumExtendedDynamicRangeColorComponentValue)],
                safety: gammaHeadroomSafety
            )
            applyGammaScale(scale, to: screen.displayID)
        }
    }

    func refreshDisplayConfiguration() {
        precondition(Thread.isMainThread)
        guard isBoosted, !isChanging else { return }
        if currentConfiguration != configuration {
            rebuildOverlays()
        }
        // Headroom changes also post screen-parameter notifications. Refresh
        // the render snapshot immediately without rebuilding the EDR context.
        let headrooms = NSScreen.screens.map { ($0.displayID, appliedHeadroom(for: $0)) }
        renderLock.lock()
        for (displayID, headroom) in headrooms {
            renderTargets[displayID]?.headroom = headroom
        }
        renderLock.unlock()
    }

    // MARK: - Display link

    private func startDisplayLink() {
        stopDisplayLink()
        var link: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&link) == kCVReturnSuccess,
              let link else { return }
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let callbackResult = CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userInfo) -> CVReturn in
            let mgr = Unmanaged<DisplayBrightnessManager>.fromOpaque(userInfo!).takeUnretainedValue()
            mgr.renderAllLayers()
            return kCVReturnSuccess
        }, selfPtr)
        guard callbackResult == kCVReturnSuccess else { return }
        if CVDisplayLinkStart(link) == kCVReturnSuccess {
            displayLink = link
        }
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    /// Keep rendered values within current granted headroom; potential
    /// headroom is for capability detection, not a safe rendering limit.
    func appliedHeadroom(for screen: NSScreen) -> Double {
        let headroom = screen.maximumExtendedDynamicRangeColorComponentValue
        return headroom.isFinite ? min(max(headroom, 1.0), maxHeadroomCap) : 1.0
    }

    // MARK: - EDR overlay

    private func createOverlays() {
        guard let device = metalDevice, let queue = commandQueue else { return }

        var targets: [CGDirectDisplayID: RenderTarget] = [:]
        for screen in NSScreen.screens {
            let maxEDR = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
            guard maxEDR > 1.0 else { continue }

            // Transparent EDR signaling window. The gamma ramp applies the
            // content boost; this window keeps an EDR rendering context alive.
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
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
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

            let headroom = appliedHeadroom(for: screen)
            renderFrame(metalLayer: metalLayer, brightness: headroom, queue: queue)
            targets[screen.displayID] = RenderTarget(
                displayID: screen.displayID, layer: metalLayer, headroom: headroom,
                lastSubmittedAt: ProcessInfo.processInfo.systemUptime
            )
            window.orderFront(nil)
            overlayWindows.append(window)
        }

        renderLock.lock()
        renderTargets = targets
        renderLock.unlock()
    }

    private func rebuildOverlays() {
        guard isBoosted else { return }
        isChanging = true
        defer { isChanging = false }
        stopDisplayLink()
        Self.resetGammaToProfile()
        removeOverlays()
        configuration = currentConfiguration
        createOverlays()
        startDisplayLink()
        refreshGamma()
    }

    private func renderAllLayers() {
        guard frameLock.try() else { return }
        defer { frameLock.unlock() }
        guard let queue = commandQueue else { return }
        renderLock.lock()
        let targets = Array(renderTargets.values)
        renderLock.unlock()
        // nextDrawable can block; never hold the state lock while rendering.
        for target in targets {
            if renderFrame(metalLayer: target.layer, brightness: target.headroom, queue: queue) {
                renderLock.lock()
                // A callback from an old layer must not revive a removed target
                // or mark its replacement healthy after a rebuild.
                if renderTargets[target.displayID]?.layer === target.layer {
                    renderTargets[target.displayID]?.lastSubmittedAt = ProcessInfo.processInfo.systemUptime
                }
                renderLock.unlock()
            }
        }
    }

    @discardableResult
    private func renderFrame(metalLayer: CAMetalLayer, brightness: Double, queue: MTLCommandQueue) -> Bool {
        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = queue.makeCommandBuffer() else { return false }

        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = drawable.texture
        desc.colorAttachments[0].loadAction = .clear
        desc.colorAttachments[0].storeAction = .store
        // Render EDR values with alpha=0: invisible to the user but signals
        // macOS to grant extended dynamic range headroom for this display.
        desc.colorAttachments[0].clearColor = MTLClearColor(
            red: brightness, green: brightness, blue: brightness, alpha: 0.0
        )

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) else { return false }
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
        return true
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
    }
}
