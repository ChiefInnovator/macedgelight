import Cocoa
import Metal
import QuartzCore

/// Boosts display brightness into XDR extended range using a full-screen Metal
/// overlay with multiply compositing. The overlay renders EDR white (2.0) and
/// composites via multiply blend, so all screen content is doubled in brightness
/// into the XDR range. Hardware backlight is also set to max via DisplayServices.
class DisplayBrightnessManager {
    static let shared = DisplayBrightnessManager()

    private(set) var isBoosted = false
    /// True while we're changing brightness, so screen-change observers can ignore the notification
    private(set) var isChanging = false

    private var overlayWindows: [NSWindow] = []
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var renderTimer: Timer?
    private var savedBrightness: [CGDirectDisplayID: Float] = [:]

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
        createOverlays()
        isBoosted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.isChanging = false }
    }

    private func deactivate() {
        isChanging = true
        renderTimer?.invalidate()
        renderTimer = nil
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
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

    // MARK: - EDR overlay

    private func createOverlays() {
        guard let device = metalDevice, let queue = commandQueue else { return }

        for screen in NSScreen.screens {
            let maxEDR = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
            guard maxEDR > 1.0 else { continue }

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

            // Layer-hosting: we own the root layer, AppKit won't reconfigure it
            let rootLayer = CALayer()
            rootLayer.isOpaque = false
            rootLayer.backgroundColor = CGColor.clear
            rootLayer.compositingFilter = "multiplyBlendMode"

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

            let brightness = min(Double(maxEDR), 2.0)
            renderFrame(metalLayer: metalLayer, brightness: brightness, queue: queue)
            window.orderFront(nil)
            overlayWindows.append(window)
        }

        // Continuously re-render and re-apply the compositing filter to prevent
        // the window server from caching stale composited content
        renderTimer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.refreshOverlays()
        }
        RunLoop.current.add(renderTimer!, forMode: .common)
    }

    private func refreshOverlays() {
        guard let queue = commandQueue else { return }
        for window in overlayWindows {
            guard let rootLayer = window.contentView?.layer,
                  let metalLayer = rootLayer.sublayers?.first as? CAMetalLayer,
                  let screen = window.screen else { continue }
            rootLayer.compositingFilter = "multiplyBlendMode"
            let brightness = min(Double(screen.maximumPotentialExtendedDynamicRangeColorComponentValue), 2.0)
            renderFrame(metalLayer: metalLayer, brightness: brightness, queue: queue)
        }
    }

    private func renderFrame(metalLayer: CAMetalLayer, brightness: Double, queue: MTLCommandQueue) {
        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = queue.makeCommandBuffer() else { return }

        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = drawable.texture
        desc.colorAttachments[0].loadAction = .clear
        desc.colorAttachments[0].storeAction = .store
        desc.colorAttachments[0].clearColor = MTLClearColor(
            red: brightness, green: brightness, blue: brightness, alpha: 1.0
        )

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: desc) else { return }
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
        drawable.present()
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
    }
}
