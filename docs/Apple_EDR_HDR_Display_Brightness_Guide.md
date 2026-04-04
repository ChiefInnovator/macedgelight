# Apple EDR/HDR Display Brightness: Complete Developer Guide

## Research Summary

This document consolidates all available Apple documentation, WWDC sessions, developer forum guidance, and community findings on building macOS applications that leverage Extended Dynamic Range (EDR) to control display brightness on HDR-capable Apple displays — with specific focus on avoiding flickering, white-screen artifacts, and other visual glitches.

---

## 1. What is EDR (Extended Dynamic Range)?

EDR is Apple's HDR representation **and** rendering pipeline. It is not just a format — it is the entire system by which macOS composites SDR and HDR content side-by-side on the same display.

**Key concepts:**

- **Reference White = 1.0**: In EDR, the value `1.0` represents SDR white (the "normal" maximum brightness). Values above 1.0 represent content brighter than SDR — this is the "headroom."
- **Headroom**: The ratio of the display's peak brightness to the current SDR reference white brightness. For example, if SDR brightness is 100 nits and the display can produce 1000 nits, headroom = 10.0.
- **EDR is adaptive**: When the user adjusts display brightness, the headroom changes dynamically. Lower brightness = more headroom. Maximum brightness = minimal headroom.
- **Clipping behavior**: By default, EDR values above the current headroom are **clipped** (not tone-mapped). This is intentional — content renders as close to the author's intent as possible.

**Source**: WWDC21 "Explore HDR rendering with EDR", WWDC22 "Explore EDR on iOS", WWDC23 "Support HDR images in your app"

---

## 2. Display Capabilities & Headroom Values

| Display | Max EDR Headroom | Notes |
|---------|-----------------|-------|
| Conventional backlit Mac displays | ~2x SDR | MacBook Air, iMac, etc. |
| iPhone XDR (14 Pro, etc.) | ~8x SDR | |
| iPad Pro Liquid Retina XDR | ~16x SDR | |
| External HDR10 displays | ~5x SDR | Via Mac, iPad, AppleTV |
| Pro Display XDR (default preset) | Up to 400x SDR | At minimum 4-nit brightness |
| Pro Display XDR (500 nit brightness) | ~3.2x SDR | Headroom shrinks at higher brightness |

**Critical insight**: Even non-HDR Apple displays support EDR (since macOS Catalina). Apple remaps "white" to something below the actual maximum, reserving headroom for HDR pixels. The OS increases backlight brightness to compensate, spending extra battery to maintain this capability.

---

## 3. The Four-Step EDR Opt-In Process (CAMetalLayer)

This is Apple's officially recommended approach from WWDC21/22/23:

### Step 1: Enable EDR on the Metal Layer

```swift
let metalLayer = CAMetalLayer()
metalLayer.wantsExtendedDynamicRangeContent = true
```

### Step 2: Set an Extended-Range Color Space

```swift
metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
```

Other valid options:
- `CGColorSpace.extendedLinearSRGB`
- BT.2020 with PQ or HLG transfer functions (for video content)

### Step 3: Use a Floating-Point Pixel Format

```swift
metalLayer.pixelFormat = MTLPixelFormat.rgba16Float
```

Also acceptable: 10-bit packed formats (`MTLPixelFormat.bgr10a2Unorm`) when combined with PQ/HLG color spaces.

### Step 4: Render Pixels with Values > 1.0

Pixel values in the 0–1 range render as normal SDR. Values above 1.0 render brighter than SDR white, up to the current EDR headroom.

**Source**: WWDC21 session 10161, Apple Metal documentation

---

## 4. Querying EDR Headroom (Critical for Avoiding White Screens)

### macOS (NSScreen)

```swift
let screen = view.window?.screen

// DYNAMIC — changes with brightness, True Tone, etc.
let currentMax = screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1.0

// STATIC — maximum possible if brightness were optimal
let potentialMax = screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1.0

// STATIC — guaranteed renderable without distortion (for reference workflows)
let referenceMax = screen?.maximumReferenceExtendedDynamicRangeColorComponentValue ?? 0.0
```

### iOS (UIScreen)

```swift
let currentHeadroom = UIScreen.main.currentEDRHeadroom       // dynamic
let potentialHeadroom = UIScreen.main.potentialEDRHeadroom     // static max
```

### When to Use Each Value

| Value | Use Case |
|-------|----------|
| `maximumPotentialExtendedDynamic...` | Check if display supports EDR at all (> 1.0 = yes). Decide whether to enable EDR or load HDR assets. |
| `maximumExtendedDynamic...` | **Use for tone mapping during rendering.** This is the current renderable max — anything above this WILL clip. |
| `maximumReferenceExtended...` | Pro apps needing guaranteed distortion-free rendering. |

### Responding to Headroom Changes

```swift
// Subscribe to screen parameter changes
NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil, queue: .main
) { _ in
    let newHeadroom = view.window?.screen?
        .maximumExtendedDynamicRangeColorComponentValue ?? 1.0
    // Re-render or re-tone-map content
}

// Also subscribe to window screen changes
NotificationCenter.default.addObserver(
    forName: NSWindow.didChangeScreenNotification,
    object: view.window, queue: .main
) { _ in
    // Headroom may differ per display
}
```

**CRITICAL**: You must query headroom on **every draw call**, not just at setup. The value changes dynamically based on display brightness, ambient light (True Tone), and other factors.

**Source**: WWDC21 session 10161, Apple Developer Forums

---

## 5. Tone Mapping — Preventing Clipping and White Screens

This is the #1 cause of "white screen" artifacts: rendering pixel values above the current EDR headroom without tone mapping.

### Option A: Use CAEDRMetadata (System Tone Mapper)

Apple's built-in tone mapper processes content so values above headroom are gracefully rolled off rather than clipped.

```swift
// For HLG content
metalLayer.edrMetadata = CAEDRMetadata.hlg

// For HDR10/PQ content
metalLayer.edrMetadata = CAEDRMetadata(
    minLuminance: 0.0,
    maxLuminance: 1000.0,
    opticalOutputScale: 100.0  // reference white in nits
)
```

**Important**: Check availability first with `CAEDRMetadata.isAvailable`.

### Option B: CALayer with Automatic Tone Mapping (WWDC23)

```swift
// New in macOS 14 / iOS 17
let layer = CALayer()
layer.wantsExtendedDynamicRangeContent = true
// CALayer automatically tone maps; CAMetalLayer does NOT
```

**The key difference**: `CALayer.wantsExtendedDynamicRangeContent` enables automatic tone mapping. `CAMetalLayer.wantsExtendedDynamicRangeContent` does NOT — it gives you raw EDR with clipping. If your content exceeds the available headroom and you're using CAMetalLayer, you MUST either:
1. Use `CAEDRMetadata` for system tone mapping, OR
2. Implement your own tone mapping, OR
3. Clamp your values to the current `maximumExtendedDynamicRangeColorComponentValue`

### Option C: Custom Tone Mapping

```swift
// In your render loop:
let edrMax = screen.maximumExtendedDynamicRangeColorComponentValue

// Simple clamp (harsh but safe)
let outputValue = min(pixelValue, edrMax)

// Soft clip (better quality)
// Apply a shoulder curve that smoothly rolls off values approaching edrMax
```

**Source**: WWDC21 session 10161, WWDC22 session 10113, WWDC23 session 10181

---

## 6. Brightness Upscaling Approaches (Making the Whole Screen Brighter)

Applications like Vivid, BetterDisplay, and BrightXDR use EDR to increase overall display brightness beyond the normal SDR maximum. There are three documented approaches:

### Approach 1: Metal Overlay (Most Common for Apps)

Used by BrightXDR, Vivid, and BetterDisplay's Metal mode:

- Create a full-screen, transparent `CAMetalLayer` window positioned above all other content
- Set `wantsExtendedDynamicRangeContent = true`
- Render a transparent overlay with EDR color values using a blending mode that multiplies/boosts the underlying pixel brightness into the HDR range
- The overlay effectively shifts all SDR content into the EDR headroom

**Known issues with this approach:**
- **White screen during Space transitions**: The overlay window can become visible as a white flash when switching between Spaces
- **Screenshot artifacts**: `Cmd+Shift+4` (window capture) captures the overlay window as white
- **Flickering during EDR ramp-up**: When the display enters EDR mode, macOS gradually ramps brightness up over 1–2 seconds while simultaneously lowering the SDR white point — this transition can cause visible flicker if not handled
- **HDR video clipping**: Since the overlay pushes SDR content into HDR range, actual HDR video content gets double-boosted and clips

### Approach 2: Color Table / Gamma Table Manipulation

Used by BetterDisplay on Apple Silicon:

- Manipulates the display's color lookup table (EOTF/gamma table) so SDR intensity values map to higher-than-normal luminance levels
- Effectively remaps the transfer function to extend SDR values into HDR brightness range
- Works only on Apple Silicon Macs with XDR or HDR displays

**Known issues:**
- HDR video content is clipped to SDR brightness levels (since the gamma table remapping uses up the HDR headroom for SDR content)
- Requires HDR to be enabled on the display
- Not available on Intel Macs

### Approach 3: Native XDR Preset Manipulation (Apple Displays Only)

Used by BetterDisplay's "native" mode:

- Uses undocumented APIs to change the display preset/configuration
- Unlocks the full brightness range natively without overlays or gamma table tricks
- No HDR video clipping, no CPU/GPU overhead, full native slider compatibility

**Known issues:**
- Uses undocumented APIs — Apple has been progressively blocking this approach (broken in macOS Tahoe 26.3)
- Only works with built-in Apple XDR displays
- External Pro Display XDR support is experimental and may cause reconnect loops

**Source**: BetterDisplay documentation, BrightXDR source code, BetterDisplay GitHub issues

---

## 7. Common Causes of Flickering and White Screen Issues

### 7.1 EDR Ramp-Up Transition

When EDR content first appears on screen, macOS performs a coordinated transition:
1. Increases the LED backlight brightness
2. Simultaneously lowers the SDR white point for all non-HDR content
3. This happens over ~1–2 seconds

If your app rapidly toggles `wantsExtendedDynamicRangeContent` or rapidly creates/destroys EDR layers, this transition animation fires repeatedly, causing visible flickering.

**Fix**: Enable EDR once and leave it enabled. Don't toggle it on/off frequently. If you need to disable the HDR effect, render SDR-range values (0–1) instead of toggling the layer property.

### 7.2 Headroom Changes Triggering App Redraws

When the display enters EDR mode, macOS sends `NSApplicationDidChangeScreenParametersNotification` to ALL running apps that might present HDR content (Safari, etc.). If multiple apps are responding to these notifications and re-rendering, it can cause a cascade of visual changes.

**Fix**: When handling headroom change notifications, smoothly interpolate your rendering values rather than jumping instantly. Consider debouncing your notification handler.

### 7.3 Rendering Above Current Headroom (White Screen)

If you render pixel values significantly above `maximumExtendedDynamicRangeColorComponentValue`, those pixels clip to the brightest white the display can produce. If this affects the entire frame, the screen appears all white.

**Fix**: Always clamp or tone-map your pixel values to the current `maximumExtendedDynamicRangeColorComponentValue`. Query this value on every frame.

### 7.4 Missing Color Space Configuration

If you set `wantsExtendedDynamicRangeContent = true` but use a non-extended color space (e.g., `displayP3` instead of `extendedLinearDisplayP3`), the rendering pipeline may produce unexpected results including washed-out colors or flicker.

**Fix**: Always use extended-range color spaces:
- `CGColorSpace.extendedLinearDisplayP3`
- `CGColorSpace.extendedLinearSRGB`

### 7.5 Incorrect Pixel Format

Using 8-bit pixel formats (e.g., `bgra8Unorm`) with EDR will clamp all values to 0–1, making EDR ineffective and potentially causing visual inconsistencies.

**Fix**: Use `rgba16Float` (preferred) or `bgr10a2Unorm` with appropriate transfer function.

### 7.6 Sleep/Wake Headroom Reset Bug

As of macOS Tahoe, `maximumExtendedDynamicRangeColorComponentValue` may incorrectly return 1.0 after sleep/wake on third-party HDR displays, even when EDR content is on screen. This is a confirmed bug filed on Apple Developer Forums.

**Fix**: After wake, re-check headroom with a short delay. Fall back to `maximumPotentialExtendedDynamicRangeColorComponentValue` if the current value returns 1.0 unexpectedly.

### 7.7 Auto-Brightness Interference

The ambient light sensor can continuously adjust display brightness while EDR is active, causing the headroom to constantly shift. This makes overlay-based brightness upscaling unstable.

**Fix**: If doing brightness upscaling, consider temporarily managing brightness independently from auto-brightness. BetterDisplay disables the ambient light sensor during active XDR upscaling.

---

## 8. Best Practices Checklist

### Setup
- [ ] Check `maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0` before enabling EDR
- [ ] Set `wantsExtendedDynamicRangeContent = true` on your CAMetalLayer
- [ ] Use `extendedLinearDisplayP3` or `extendedLinearSRGB` color space
- [ ] Use `rgba16Float` pixel format
- [ ] Enable EDR once — do NOT toggle it on/off repeatedly

### Rendering Loop
- [ ] Query `maximumExtendedDynamicRangeColorComponentValue` on EVERY draw call
- [ ] Subscribe to `NSApplication.didChangeScreenParametersNotification` and `NSWindow.didChangeScreenNotification`
- [ ] Tone map or clamp pixel values to current headroom
- [ ] Use `CAEDRMetadata` for video content to get system tone mapping for free
- [ ] Smoothly interpolate brightness changes — never jump instantaneously

### Power & Performance
- [ ] Only enable EDR when there is both HDR content AND available headroom
- [ ] FP16 buffers consume more bandwidth than 8-bit buffers — be mindful on battery
- [ ] CAEDRMetadata tone mapping adds a processing pass — increases latency

### Avoiding Artifacts
- [ ] Never render full-screen pixel values above current headroom without tone mapping
- [ ] Handle sleep/wake gracefully — re-query headroom after wake
- [ ] Test with varying display brightness levels (headroom changes dramatically)
- [ ] Test on both built-in and external displays (different headroom profiles)
- [ ] Test in Reference Mode (fixed 100 nit SDR, 1000 nit HDR = 10x headroom)

---

## 9. Key Apple Documentation & WWDC Sessions

### Primary WWDC Sessions
| Session | Year | Focus |
|---------|------|-------|
| Explore HDR rendering with EDR (10161) | WWDC21 | Core EDR concepts, 4-step opt-in, NSScreen APIs, best practices |
| Explore EDR on iOS (10113) | WWDC22 | iOS EDR APIs, UIScreen headroom, Reference Mode |
| Display EDR content with Core Image, Metal, and SwiftUI (10114) | WWDC22 | Core Image + EDR sample code |
| Display HDR video in EDR with AVFoundation and Metal (110565) | WWDC22 | Video pipeline with EDR |
| Support HDR images in your app (10181) | WWDC23 | CALayer tone mapping vs CAMetalLayer, ISO HDR |
| Support Apple Pro Display XDR in your apps (Tech Talk 10023) | 2022 | Reference modes, custom presets, headroom parameters |
| Metal for Pro Apps (608) | WWDC19 | Original EDR API introduction |

### Apple Developer Documentation Pages
- [HDR Content (Metal)](https://developer.apple.com/documentation/metal/hdr-content)
- [Displaying HDR Content in a Metal Layer](https://developer.apple.com/documentation/metal/displaying-hdr-content-in-a-metal-layer)
- [wantsExtendedDynamicRangeContent](https://developer.apple.com/documentation/quartzcore/cametallayer/wantsextendeddynamicrangecontent)
- [edrMetadata](https://developer.apple.com/documentation/quartzcore/cametallayer/edrmetadata)
- [maximumExtendedDynamicRangeColorComponentValue](https://developer.apple.com/documentation/appkit/nsscreen/1388362-maximumextendeddynamicrangecolor)
- [maximumPotentialExtendedDynamicRangeColorComponentValue](https://developer.apple.com/documentation/appkit/nsscreen/maximumpotentialextendeddynamicrangecolorcomponentvalue)
- [maximumReferenceExtendedDynamicRangeColorComponentValue](https://developer.apple.com/documentation/appkit/nsscreen/maximumreferenceextendeddynamicrangecolorcomponentvalue)
- [Use reference modes with your Apple display](https://support.apple.com/en-us/108321)

### Open Source Reference Implementations
- [BrightXDR](https://github.com/starkdmi/BrightXDR) — Metal overlay approach (archived, use BrightIntosh instead)
- [TryAppleEDR](https://github.com/xzhih/TryAppleEDR) — EDR headroom exploration and testing
- [BetterDisplay](https://github.com/waydabber/BetterDisplay) — Multiple upscaling methods documented

### Known Apple Bugs (as of macOS Tahoe 26.x)
- `maximumExtendedDynamicRangeColorComponentValue` returns 1.0 after sleep/wake on third-party HDR displays
- Native XDR brightness upscaling via preset management broken in macOS Tahoe 26.3
- Auto-brightness interference with EDR mode on Apple Silicon

---

## 10. Architecture Decision: Overlay vs. Color Table vs. Native

| Factor | Metal Overlay | Color Table | Native Preset |
|--------|--------------|-------------|---------------|
| GPU overhead | Medium (rendering overlay each frame) | None | None |
| HDR video compatibility | Clips HDR video | Clips HDR video | Full compatibility |
| Display support | All HDR/XDR displays | Apple Silicon + XDR/HDR only | Built-in Apple XDR only |
| macOS compatibility | Stable across versions | Stable on Apple Silicon | Breaking in recent macOS |
| Flickering risk | High (Space transitions, ramp-up) | Low | Very low |
| White screen risk | Medium (overlay visibility) | Low | Very low |
| API status | Public APIs only | Public APIs (color tables) | Undocumented APIs |

**Recommendation**: For a production application, the Metal overlay approach using public APIs is the most broadly compatible. To minimize flickering and white-screen artifacts:

1. Use `CAMetalLayer` with proper EDR configuration (not toggling on/off)
2. Always query and respect current headroom
3. Handle EDR ramp-up transitions gracefully
4. Implement smooth interpolation for brightness changes
5. Account for Space transitions and window ordering
6. Test exhaustively across brightness levels, sleep/wake cycles, and display types
