# MacEdgeLight — Technical Specification

App version 3.1.0 | November 2026 | Richard Crane

## Overview

MacEdgeLight is a macOS menu bar utility that renders an ambient glowing border around the screen. Built with Swift and AppKit using Core Graphics for rendering. No SwiftUI dependencies.

**Bundle ID:** `com.richardcrane.macedgelight`
**Min OS:** macOS 13 Ventura
**Architecture:** Universal (arm64 + x86_64)
**Sandboxed:** No (required for overlay windows and desktop icon control)

## Architecture

```
MacEdgeLightApp (entry point)
├── EdgeLightManager (central controller)
│   ├── AppSettings (singleton, UserDefaults-backed)
│   ├── MonitorManager
│   │   └── EdgeLightOverlayWindow[] (one per screen)
│   │       └── EdgeLightView (Core Graphics rendering)
│   ├── ControlPanelWindow (floating HUD toolbar)
│   ├── StatusBarController (menu bar icon + dropdown)
│   ├── HotkeyManager (global keyboard shortcuts)
│   ├── LoginItemManager (launch at login via SMAppService)
│   ├── DisplayBrightnessManager (XDR brightness boost)
│   ├── MagnifierWindow (cursor magnifier loupe)
│   └── EDRInfoWindow (debug-only EDR diagnostics panel)
```

### Data Flow

```
User input (button / hotkey / menu)
  → EdgeLightManager
    → AppSettings (update + persist to UserDefaults)
    → MonitorManager.applySettingsToAll()
      → EdgeLightOverlayWindow.applySettings()
        → EdgeLightView property setters
          → startAnimationIfNeeded()
            → animationTick() at 60fps
              → needsDisplay = true
                → draw(_:) with Core Graphics
```

## Settings

| Property | Type | Default | Range | Persisted |
|---|---|---|---|---|
| brightness | Double | 1.0 | 0.2 – 2.0 | Yes |
| colorTemperature | Double | 0.5 | 0.0 – 1.0 | Yes |
| isLightOn | Bool | true | — | Yes |
| showControlPanel | Bool | true | — | Yes |
| currentMonitorIndex | Int | 0 | 0 – N | Yes |
| showOnAllMonitors | Bool | false | — | Yes |
| launchAtLogin | Bool | false | — | Yes |
| menuBarMode | Int | 2 | 0, 1, 2 | Yes |
| cursorRevealEnabled | Bool | false | — | Yes |
| desktopIconsHidden | Bool | false | — | Yes |
| visibleInCapture | Bool | false | — | Yes |
| borderWidth | Double | 60.0 | 10 – 150 | Yes |
| magnifierEnabled | Bool | false | — | Yes |
| edrBoosted | Bool | false | — | Yes |
| boostLevel | Double | 1.0 | 0.1–1.0 | Yes (invalid or missing values load as 1.0; full reset restores 1.0) |

### Menu Bar Modes

| Value | Name | Behavior |
|---|---|---|
| 0 | Below | Light stays below the menu bar. Window level = mainMenu - 1. topInset = menuBarHeight. |
| 1 | Extend | Light covers the menu bar. Window level = mainMenu + 1. topInset = 0. |
| 2 | Auto | Light extends over menu bar. When cursor enters menu bar area (y >= visibleFrame.maxY), topInset animates to menuBarHeight. When cursor leaves, topInset animates back to 0. Tracked at 30fps. |

### Migration

Old versions stored `extendOverMenuBar` as a Bool. On first launch with the new setting, the app checks:
- If `menuBarMode` key exists in UserDefaults → use it
- If old `extendOverMenuBar` was true → set `menuBarMode = 1`
- Otherwise → set `menuBarMode = 2` (new default)

## Rendering Pipeline

All rendering happens in `EdgeLightView.draw(_:)` using Core Graphics.

### Pass 1: Outer Glow

Concentric expanding rounded rectangles drawn outward from the frame edge. Each ring is a frame shape (expanded outer minus contracted inner) filled with the base color at decreasing opacity.

```
for i in stride(from: glowRadius, through: 1, by: -2):
    alpha = baseAlpha * 0.03 * (1.0 - i / glowRadius)
    draw frame at expansion = i, using even-odd fill
```

### Pass 2: Solid Frame

The main visible border. Frame shape = outerRect minus innerRect, clipped with even-odd rule. Filled with a diagonal linear gradient:

```
white(0.95) → tinted(0.9) → fullColor(0.95) → tinted(0.9) → white(0.95)
at locations: 0.0, 0.3, 0.5, 0.7, 1.0
gradient direction: top-left → bottom-right
```

### Pass 3: Inner Glow

Similar to outer glow but bleeding inward from the inner frame edge. Uses 60% of the glow radius with slightly higher alpha (0.04).

### Pass 4: Bloom

Activated when `displayedBrightness > 1.0`. Uses `.plusLighter` blend mode (additive compositing).

1. **Frame bloom**: Clips to frame shape, fills with white at `(brightness - 1.0) * 0.6` alpha
2. **Glow bloom**: Expanding rings at `glowRadius + glowRadius * bloom`, stepping by -4, with 5% alpha falloff

At brightness 2.0 (maximum), bloom radius doubles and the effect is intensely bright.

### Pass 5: Cursor Cutout

When cursor reveal is enabled, draws a radial gradient in `.destinationOut` blend mode:

```
center → 50% radius: fully opaque (complete punch-through)
50% radius → 100% radius: opacity fades to 0
radius: 60pt
```

### Color Temperature

Linearly interpolates between cool and warm:
- Temperature 0.0: RGB(220, 235, 255) — cool blue-white
- Temperature 0.5: RGB(237, 227, 217) — neutral
- Temperature 1.0: RGB(255, 220, 180) — warm amber

## Animation System

All animated properties use exponential lerp at 60fps:

```
displayedValue += (targetValue - displayedValue) * 0.12
```

This gives smooth ease-out behavior, settling to within 0.2% in ~25 frames (~0.4 seconds).

**Animated properties:** brightness, colorTemperature, topInset, frameThickness

**Timer management:** Timers are created with `Timer(timeInterval:repeats:)` and added to `RunLoop.current` in `.common` mode. This is critical — `.common` includes both `.default` and `.eventTracking` modes, allowing animations to run while buttons are held down (RepeatButton mouse tracking loop runs in `.eventTracking`).

**Settlement:** When all properties are within threshold of their targets, the timer is invalidated to avoid unnecessary CPU usage.

## Window Hierarchy

| Window | Level | Type | Click-through |
|---|---|---|---|
| XDR brightness overlay | screenSaver - 1 | NSWindow | Yes (ignoresMouseEvents) |
| EDR diagnostics | mainMenu + 3 | NSPanel | No (debug only) |
| EdgeLightOverlayWindow | mainMenu ± 1 | NSWindow | Yes (ignoresMouseEvents) |
| ControlPanelWindow | mainMenu + 2 | NSPanel | No (interactive, canBecomeKey for tooltips) |
| MagnifierWindow | mainMenu + 3 | NSPanel | Yes (ignoresMouseEvents) |
| macOS menu bar | mainMenu (24) | System | — |

The control panel must be above the overlay to remain visible when the border is thick.

### Overlay Window Properties

- `isOpaque = false` — transparent background
- `backgroundColor = .clear`
- `hasShadow = false`
- `ignoresMouseEvents = true` — all clicks pass through
- `sharingType = .none` — hidden from screen capture (togglable to `.readOnly`)
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`

## XDR Brightness Boost

On displays that support Extended Dynamic Range (MacBook Pro 14/16 with M1 Pro/Max+, Pro Display XDR), a toggle enables full XDR brightness using a dual technique:

### Invisible Metal EDR Overlay

1. A full-screen borderless overlay window with a `CAMetalLayer` sublayer
2. The Metal layer uses `.rgba16Float` pixel format and `CGColorSpace.extendedLinearDisplayP3`
3. `wantsExtendedDynamicRangeContent = true` signals the compositor to unlock XDR mode
4. The Metal layer renders EDR values with **alpha=0** — invisible to the user but signals macOS to grant extended headroom
5. A `CVDisplayLink` re-renders every frame to prevent EDR headroom decay
6. No compositing filter — the overlay does not visually affect screen content

### Linear Gamma Scaling

The display's gamma transfer table is replaced with a freshly generated linear ramp scaled by up to `gammaScale` (2.4x):

```swift
boosted[i] = Float(i) / Float(count - 1) * gammaScale
```

This pushes pixel values proportionally into the EDR range. Unlike power-curve gamma (which compresses midtones and causes washout), linear scaling preserves relative contrast — blacks stay black, everything else gets proportionally brighter. The ramp is generated from scratch on every apply rather than reading the live LUT, so a crashed run, dirty sleep cycle, or re-entrant activation cannot double-scale an already boosted table.

The user-selected strength (`boostLevel`, menu: 10/25/50/75/100%) is applied against `gammaScale` (the ceiling): `applied = 1.0 + level × (safeCeiling − 1.0)`. Level 1.0 equals the ceiling (3.0.4 behavior) and the range never dips below the neutral 1.0 or above the ceiling. Changing the level rewrites the ramp immediately without touching overlays, recovery state, or `edrBoosted`; `DisplayBrightnessManager` receives it by assignment and does not import `AppSettings`. Conflict detection: at the start of each maintenance tick, before writing, the live table is read and compared with the last ramp this process wrote to that display (all samples, all channels, tolerance 0.002; the written ramp is linearly interpolated when the display reports a different sample count). Comparison is skipped for 3 seconds after activation, overlay rebuild, or deactivation, and after a failed write. A display is in conflict after 3 mismatches within 6 seconds (not necessarily consecutive) and clears after 10 seconds without one. A conflict never clears `edrBoosted` or stops writes; the menu and HUD show CONFLICT (WAITING takes precedence) and the user can turn boost off. This is a heuristic, not proof of another writer. The ramp is not clamped to live headroom: if macOS grants less than 2.4x, content above the granted headroom clips. The neutral floor is 1.0. A main-run-loop timer in `.common` mode reasserts a fresh ramp every 0.5 seconds, even when headroom has not changed, repairing LUT resets by macOS. Failed writes are logged and retried on subsequent ticks. Invalid headroom falls back to a neutral scale. There is no headroom margin; macOS cannot be forced to sustain a fixed luminance. Night Shift, True Tone, and hardware calibration are bypassed by the synthetic ramp while boost is active and restored via ColorSync on deactivation.

### Hardware Brightness

Hardware backlight is intentionally left unchanged. The boost uses only the synthetic gamma ramp plus EDR headroom signaling so toggles apply within a compositor frame and do not inherit the visible ramp/latency of system brightness changes.

### Constants

| Constant | Value | Purpose |
|---|---|---|
| `maxHeadroomCap` | 16.0 | Maximum EDR headroom requested from macOS |
| `gammaScale` | 2.4 | Linear gamma table multiplier |

### Lifecycle

The overlay window sits at `screenSaver - 1` and joins full-screen Spaces. `DisplayBrightnessManager` is a singleton with idempotent `setEnabled(_:)` and `restore()` methods. `AppSettings.edrBoosted` stores user intent, separately from the active renderer. Controls show that persisted preference and indicate when an enabled boost is waiting for a display or session. A user can disable the preference even while no supported display is connected. Deactivation stops rendering and maintenance synchronously, then restores ColorSync and removes overlays. There are no queued gamma writes after teardown.

Availability is checked via `NSScreen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0`.

### Sleep/Wake Resilience

System sleep, display-only sleep, screen lock, and user-session deactivation suspend the renderer without clearing `AppSettings.edrBoosted`. A `.common` main-run-loop timer checks recovery eligibility every 0.5 seconds without a retry limit, including when an EDR display is initially unavailable. Wake and display wake allow 2 seconds to settle; unlock and session activation allow 0.75 seconds. Overlapping events cannot shorten an existing settle period. Notification handlers pass typed events through one recovery-state transition function. Repeated start/stop calls are idempotent, and termination stops recovery before other cleanup. Notifications suspend immediately, and `CGSessionCopyCurrentDictionary` must also report a logged-in, on-console, unlocked session before reactivation. A user toggle off, a new suspension, or app stop prevents recovery.

Display topology changes rebuild EDR overlays and refresh gamma; headroom-only changes do not rebuild them. Each render target owns its display ID, layer, headroom, and last submission timestamp. The Metal display-link thread uses a synchronized snapshot and never reads AppKit screens or writes gamma. Stale callbacks cannot update a removed or replaced target. Maintenance monitors submissions for each overlay and rebuilds after a 2-second stall. If display-link creation/start fails, maintenance provides fallback frame submissions. The layer retains EDR opt-in while active and renders within current headroom (capped at 16). Headroom notifications refresh the synchronized render snapshot without tearing down the EDR context. Gamma also respects current headroom.

Actual logout terminates the app. Enable **Launch at Login** for automatic restoration in the next user session. The app does not boost the login window or a sleeping display, and macOS retains control over thermal, power, and brightness limits.

Manual hardware validation (required beyond unit tests): leave boost enabled through repeated system sleep/wake, display-only sleep, lock/unlock, fast user switching, logout/login with Launch at Login enabled, full-screen Spaces, and external-display disconnect/reconnect. Verify that disabling during recovery stays off, different displays recover independently, and a sustained session does not fade after a ColorSync reset. Check gamma/profile restoration after quitting. These physical transitions are not simulated by unit tests.

### Boost Regression Checks

- `make test` covers all 24 orderings of system wake, display wake, unlock, and session activation; 1,000 simulated sleep cycles; delayed session/display availability; cancellation; and gamma safety across rising/falling headroom.
- `bash scripts/test-boost-hardware.sh` compiles the production brightness manager into a standalone harness. Quit MacEdgeLight first. The harness temporarily activates boost without changing saved preferences, verifies actual gamma readback, forces ColorSync resets in normal and event-tracking run-loop modes, samples gamma for 30 seconds, and checks that shutdown leaves the restored LUT unchanged for 2 seconds. It restores ColorSync on completion, a caught test failure, or ordinary SIGINT/SIGTERM cancellation. Do not force-kill the harness while it is changing the display.
- `bash scripts/test-boost-hardware.sh --thread-sanitizer` runs the same live rendering checks with race detection enabled. This validates only paths exercised on the connected display; it does not simulate sleep, logout, GPU failure, or cable removal.
- For release acceptance, run at least 10 physical sleep/wake and lock/unlock cycles, then a two-hour session covering full-screen apps, normal menu use, and AC/battery changes. Record recovery time, live headroom, gamma-write failures, CPU/memory growth, and any visible fade or clipping. A stable gamma readback is not a measurement of physical luminance; fixed-brightness verification requires a meter and controlled conditions.

## EDR Diagnostics Window

Debug-only floating panel (`EDRInfoWindow`) that appears when running under Xcode debugger (detected via `P_TRACED` process flag). Displays real-time per-screen EDR information updated every 0.5 seconds:

- EDR boost status, hardware backlight level
- Current/potential/reference headroom values
- Applied multiply (our headroom cap) or n/a when off
- Effective vs peak brightness percentage
- Gamma deviation per channel (R/G/B) with own-vs-external attribution
- External EDR activity detection (warns when another app is using EDR)
- Active color space (named, ICC profile, or model fallback)

Features a titlebar copy button (SF Symbol `doc.on.doc`) that copies a timestamped diagnostic snapshot to the clipboard.

## Control Panel

### Button Layout

Buttons are split into two groups separated by a thin vertical divider:

**Light-dependent** (dimmed at 40% alpha when light is off): brightness up/down, color warmer/cooler, border thicker/thinner, next monitor, all monitors, menu bar mode, cursor reveal, screen capture

**Always-active**: toggle light, XDR brightness, magnifier, desktop icons, reset, hide controls; Launch at Login and Quit are menu commands

All boolean menu toggles show ON/OFF and checkmarks from the current settings: ring light, all monitors, cursor reveal, magnifier, screen capture, hidden desktop icons, controls visibility, and Launch at Login. Boost distinguishes ON, OFF, unsupported, and WAITING; a pending request stays cancellable. Menu-bar mode names Below/Extend/Auto explicitly. The status bar bulb uses filled/outline icons and an ON/OFF tooltip for the ring light.

Menu state refreshes after settings changes and when opening the menu, so startup, toolbar/keyboard actions, and resets stay synchronized. Light-dependent menu commands follow the toolbar's enabled state. Toolbar toggles expose state through their icons, ON/OFF tooltips, button state, and accessibility values. Boost exposes WAITING while recovering. Launch at Login reads actual system registration after a request and when opening the menu. Reset hides the magnifier window as well as clearing its setting.

### Button Types

- **NSButton** — Standard click buttons (monitors, reset, hide controls, etc.)
- **RepeatButton** (custom subclass) — Fires action on press, then repeats fine-step closure at 35ms intervals after 250ms hold delay. Uses native `NSButton`/cell tracking with a fine-action Timer in `.common` run-loop mode. Release, pointer exit, disable, hide/detach, panel auto-hide, order-out and close cancel permanently until a new press. Keyboard/accessibility activation performs one coarse action. The six adjustment tooltips and accessibility help explain click, hold for fine steps, and moving away to stop; accessible names stay concise.
- **DoubleClickButton** (custom subclass) — Fires normal action on single click, calls `onDoubleClick` closure on double-click. Used for lightbulb (toggle / reset).

### Dynamic Background

The control panel's background opacity adjusts based on glow overlap:

```
overlap = borderWidth + max(0, brightness - 1.0) * 40
intensity = clamp((overlap - 40) / 100) * brightness
backgroundColor alpha = min(0.85, intensity * 0.8)
```

When the light is off, the background resets to the baseline dark background (0.1 white, 0.95 alpha).

### Baseline Background

The panel uses active `.hudWindow` material with behind-window blending and a separate background layer. At setup and with the ring off, the layer is `NSColor(white: 0.1, alpha: 0.95)`. With the ring on, the overlap formula replaces that layer with 0.05 white and alpha 0–0.85 (0.16 at default ring settings). Material still contributes the backdrop; source arithmetic alone does not establish rendered contrast.

## Multi-Monitor

- `MonitorManager` queries `NSScreen.screens` and creates one `EdgeLightOverlayWindow` per screen
- Each overlay is sized to its screen's `frame`
- Screen changes detected via `NSApplication.didChangeScreenParametersNotification`
- On change: validate monitor index and reposition control panel; resize existing overlays when display IDs are unchanged, recreate them when the topology changes

## Cursor Tracking

### Cursor Reveal (60fps)

Timer polls `NSEvent.mouseLocation` and converts to view-local coordinates. Sets `edgeLightView.cursorPosition` which triggers immediate redraw (no lerp — cutout follows cursor exactly).

### Menu Bar Auto-Reveal (30fps)

Timer polls cursor position through the production screen-band predicate: X and Y must be within the screen’s half-open frame bounds, and Y must be at or above `screen.visibleFrame.maxY`. This excludes adjacent/stacked displays and zero-height menu bands. When cursor enters the menu bar zone, sets `topInset = menuBarHeight` which triggers animated retraction. When cursor leaves, sets `topInset = 0`.

## Display Quality

### Retina/HiDPI

Core Graphics automatically renders at the window's backing scale factor. All coordinates are in points; the system scales to device pixels. No manual scale handling needed.

### Wide-Gamut Color

Gradients use `window?.screen?.colorSpace?.cgColorSpace` instead of `CGColorSpaceCreateDeviceRGB()`. This ensures accurate color on P3 displays (MacBook Pro, Studio Display, Pro Display XDR). Falls back to device RGB if the display color space is unavailable.

## Global Hotkeys

`HotkeyManager` uses local/global `NSEvent` key-down monitors with Carbon key-code constants:

| Shortcut | Action |
|---|---|
| Cmd + Shift + L | Toggle light on/off |
| Cmd + Shift + Up | Increase ring brightness |
| Cmd + Shift + Down | Decrease ring brightness |
| Cmd + Shift + B | Toggle display brightness boost |
| Five Q taps within two seconds, no modifiers | Panic quit |

## Build & Release

### Build Commands

```bash
make build       # Debug build (xcodebuild)
make release     # Archive + DMG + zip
make dmg         # Styled DMG with create-dmg
make zip         # Zip of .app bundle
make clean       # Clean build artifacts
```

### DMG

Built with `create-dmg`. Custom background generated by `generate_dmg_bg.swift` — slate-blue gradient with branding text (MacEdgeLight, Richard Crane, Inventing Fire with AI). App icon on left, Applications symlink on right, directional arrow between them.

### App Icon

Generated programmatically by `generate_icon.swift`. Deep blue-purple gradient background with warm edge glow ring and two overlapping white application windows with blue-gray title bars and traffic light dots. All 10 macOS icon sizes (16px through 1024px at 1x and 2x).

### Rapid manual brightness toggles

After manually disabling an active boost, `BoostRecoveryState` waits 30 seconds before permitting reactivation. A quick re-enable preserves the requested on-state and recovery retries automatically after the deadline. Disabling an already queued request cancels it without restarting the interval. Initial activation is immediate; lock, sleep, session, and display checks still apply. Pending UI uses an hourglass and countdown tooltip, plus a Waiting menu label. This is a conservative workaround for a reported compositor/display recovery delay, not proof of its cause or a physical luminance guarantee.

### Code Signing & Notarization

Release distribution uses Xcode automatic signing with MILL5 (`FS6453639M`), Hardened Runtime, and registered App ID `com.richardcrane.macedgelight`. Developer ID exports are notarized by Apple and checked with Gatekeeper before packaging.

```bash
make release            # Xcode archive → automatic Developer ID signing → notarize → export → package
make package            # Package a notarized app exported by Organizer into build/export/
make release-unsigned   # Quick build without signing (for testing)
```

Xcode authenticates using the Apple account in Settings → Accounts. Export options are in `scripts/ExportOptions-export.plist` and `scripts/ExportOptions-upload.plist`. A rejected Xcode login must be refreshed in Xcode; the previous `MacEdgeLightNotarize` profile is no longer used. Packaging refuses an export with a mismatched version, invalid signature, missing notarization ticket, or rejected Gatekeeper assessment.

## File Manifest

| File | Purpose |
|---|---|
| MacEdgeLightApp.swift | App entry point, NSApplicationDelegate |
| AppSettings.swift | Singleton settings, UserDefaults persistence |
| EdgeLightManager.swift | Central controller, wires all components |
| EdgeLightView.swift | Core Graphics rendering, animation timer |
| EdgeLightOverlayWindow.swift | Fullscreen overlay, cursor + menu bar tracking |
| MonitorManager.swift | Multi-monitor overlay management |
| ControlPanelWindow.swift | Floating HUD toolbar, RepeatButton, DoubleClickButton |
| StatusBarController.swift | Menu bar icon and dropdown menu |
| HotkeyManager.swift | Global keyboard shortcuts (Carbon Events) |
| LoginItemManager.swift | Launch at login (SMAppService) |
| DisplayBrightnessManager.swift | XDR brightness boost via invisible Metal EDR overlay + linear gamma scaling |
| MagnifierWindow.swift | Floating magnifier loupe following cursor |
| EDRInfoWindow.swift | Debug-only EDR diagnostics panel (visible when debugger attached) |
| generate_icon.swift | Programmatic app icon generator |
| generate_dmg_bg.swift | DMG background image generator |
| Makefile | Build, archive, DMG, zip, release |
