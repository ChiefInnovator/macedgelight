# MacEdgeLight — Technical Specification

Version 1.0 | March 2026 | Richard Crane

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
│   └── LoginItemManager (launch at login via SMAppService)
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
| EdgeLightOverlayWindow | mainMenu ± 1 | NSWindow | Yes (ignoresMouseEvents) |
| ControlPanelWindow | mainMenu + 2 | NSPanel | No (interactive) |
| macOS menu bar | mainMenu (24) | System | — |

The control panel must be above the overlay to remain visible when the border is thick.

### Overlay Window Properties

- `isOpaque = false` — transparent background
- `backgroundColor = .clear`
- `hasShadow = false`
- `ignoresMouseEvents = true` — all clicks pass through
- `sharingType = .none` — hidden from screen capture (togglable to `.readOnly`)
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`

## Control Panel

### Button Types

- **NSButton** — Standard click buttons (toggle light, monitors, quit, etc.)
- **RepeatButton** (custom subclass) — Fires action on press, then repeats fine-step closure at 35ms intervals after 250ms hold delay. Uses `window.nextEvent(matching:until:inMode:dequeue:)` for mouse tracking.
- **DoubleClickButton** (custom subclass) — Fires normal action on single click, calls `onDoubleClick` closure on double-click. Used for lightbulb (toggle / reset).

### Dynamic Background

The control panel's background opacity adjusts based on glow overlap:

```
overlap = borderWidth + max(0, brightness - 1.0) * 40
intensity = clamp((overlap - 40) / 100) * brightness
backgroundColor alpha = min(0.85, intensity * 0.8)
```

When the light is off, the background clears to fully transparent (pure HUD material).

## Multi-Monitor

- `MonitorManager` queries `NSScreen.screens` and creates one `EdgeLightOverlayWindow` per screen
- Each overlay is sized to its screen's `frame`
- Screen changes detected via `NSApplication.didChangeScreenParametersNotification`
- On change: validate monitor index, recreate all overlays, reposition control panel

## Cursor Tracking

### Cursor Reveal (60fps)

Timer polls `NSEvent.mouseLocation` and converts to view-local coordinates. Sets `edgeLightView.cursorPosition` which triggers immediate redraw (no lerp — cutout follows cursor exactly).

### Menu Bar Auto-Reveal (30fps)

Timer polls cursor position and checks if `mouseLocation.y >= screen.visibleFrame.maxY`. When cursor enters the menu bar zone, sets `topInset = menuBarHeight` which triggers animated retraction. When cursor leaves, sets `topInset = 0`.

## Display Quality

### Retina/HiDPI

Core Graphics automatically renders at the window's backing scale factor. All coordinates are in points; the system scales to device pixels. No manual scale handling needed.

### Wide-Gamut Color

Gradients use `window?.screen?.colorSpace?.cgColorSpace` instead of `CGColorSpaceCreateDeviceRGB()`. This ensures accurate color on P3 displays (MacBook Pro, Studio Display, Pro Display XDR). Falls back to device RGB if the display color space is unavailable.

## Global Hotkeys

Registered via `HotkeyManager` using Carbon Event Manager APIs:

| Shortcut | Action |
|---|---|
| Cmd + Shift + L | Toggle light on/off |
| Cmd + Shift + Up | Increase brightness |
| Cmd + Shift + Down | Decrease brightness |

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

### Code Signing & Notarization

Signed with Developer ID Application certificate (MILL5, LLC) and notarized by Apple. Users get zero Gatekeeper warnings on launch.

```bash
make release            # Full pipeline: archive → sign → notarize → staple → DMG + zip
make release-unsigned   # Quick build without signing (for testing)
```

Notarization credentials stored in keychain as `MacEdgeLightNotarize` profile.

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
| generate_icon.swift | Programmatic app icon generator |
| generate_dmg_bg.swift | DMG background image generator |
| Makefile | Build, archive, DMG, zip, release |
