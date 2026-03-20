# MacEdgeLight

A macOS ambient edge light that wraps your screen in a glowing frame. Inspired by [Windows Edge Light](https://github.com/shanselman/EdgeLight) by Scott Hanselman.

## Features

**Edge Light Overlay**
- Smooth glowing border around your entire screen with rounded corners
- Adjustable brightness from subtle (20%) to blazing bloom (200%)
- Color temperature control from cool blue-white to warm amber
- Adjustable border width (10px–150px)
- Click-through — never interferes with your work
- Hidden from screen capture by default (invisible in Zoom, Teams, or recordings)
- Toggle screen capture visibility to show the glow in recordings and streams
- Hold any adjustment button for continuous fine-grained control

**Bloom Mode**
- Push brightness past 100% for an additive white-hot bloom effect
- Glow radius expands and intensifies at higher brightness levels
- Smooth animated transitions between all settings

**Cursor Reveal**
- Toggle a feathered circular cutout that follows your cursor
- See through the glow wherever your mouse goes
- Soft-edged reveal with solid center fading to full glow

**Menu Bar Control**
- Three modes: Below, Extend, and Auto
- **Below** — light stays under the menu bar
- **Extend** — light covers the menu bar
- **Auto** — light extends over menu bar but smoothly reveals it when your cursor enters the menu bar area, then extends back when you move away

**Desktop Icons**
- Show/hide all desktop icons with one click
- Clean desktop for presentations, screencasts, or focus time

**Multi-Monitor**
- Show on a single monitor or all monitors simultaneously
- Cycle between monitors with a button press
- Adapts automatically when monitors are plugged in or removed

**Auto-Hiding Controls**
- Floating HUD toolbar with quick access to everything
- Fades away after 3 seconds of inactivity
- Reappears instantly on hover
- Toggle buttons swap to filled icons when active
- Background dynamically darkens when overlapping the glow for readability

**Reset to Defaults**
- Double-click the lightbulb to reset all light settings
- Reset button on the control bar
- "Reset to Defaults" in the status bar menu

**Menu Bar App**
- Runs as a lightweight menu bar utility (no Dock icon)
- Full controls accessible from the menu bar icon
- Optional launch at login

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd + Shift + L` | Toggle light on/off |
| `Cmd + Shift + Up` | Increase brightness |
| `Cmd + Shift + Down` | Decrease brightness |

## Control Bar

The floating toolbar provides quick access to all features:

| Icon | Function | Toggle |
|---|---|---|
| Sun (dim) | Decrease brightness (hold to fine-adjust) | |
| Sun (bright) | Increase brightness (hold to fine-adjust) | |
| Flame | Warmer color temperature (hold to fine-adjust) | |
| Snowflake | Cooler color temperature (hold to fine-adjust) | |
| Compress | Thinner border (hold to fine-adjust) | |
| Expand | Thicker border (hold to fine-adjust) | |
| Lightbulb | Toggle light on/off — double-click to reset | Filled when on |
| Monitor | Switch to next monitor | |
| Monitors | All monitors mode | Filled when on |
| Menu bar | Menu bar mode: Below → Extend → Auto | Cycles through 3 states |
| Circle | Cursor reveal mode | Filled when on |
| Video | Show in screen capture | Filled when on |
| Eye | Hide desktop icons | Swaps to eye.slash |
| Reset | Reset all settings to defaults | |
| X | Quit | |

## Requirements

- macOS 13 Ventura or later

## Installation

Download the latest `.dmg` or `.zip` from [Releases](https://github.com/ChiefInnovator/macedgelight/releases).

Since the app is not signed with an Apple Developer ID, macOS Gatekeeper will block it on first launch. To fix this, open Terminal and run:

```bash
xattr -cr /Applications/MacEdgeLight.app
```

Or: right-click the app, choose **Open**, then click **Open** in the dialog.

## Building

Open `MacEdgeLight.xcodeproj` in Xcode and build, or use the Makefile:

```bash
make build       # Debug build
make release     # Build DMG + zip for distribution
make dmg         # DMG only (drag-to-Applications)
make zip         # Zip only
make clean       # Clean build artifacts
```

The app runs without sandbox entitlements to allow the overlay window and desktop icon control.

## How It Works

The edge light is rendered in a fullscreen, click-through overlay window using Core Graphics. Each frame is drawn with multiple layered passes:

### Rendering Pipeline

1. **Outer glow** — Concentric expanding rounded rectangles drawn outward from the frame edge, each with decreasing opacity (`alpha * 0.03 * falloff`). Creates the soft light spill effect around the border.

2. **Solid frame** — The main visible border. A frame shape (outer rect minus inner rect) is filled with a diagonal linear gradient (white → tinted → white) using even-odd clipping. Color temperature shifts the tint from cool blue-white (220, 235, 255) to warm amber (255, 220, 180).

3. **Inner glow** — Similar to outer glow but bleeding inward from the frame edge, giving the border a soft volumetric look rather than a hard cutoff.

4. **Bloom mode** — When brightness exceeds 100%, the excess is rendered as additive light using `.plusLighter` blend mode. This creates a white-hot bloom effect: first an additive fill over the solid frame, then expanding glow rings (`glowRadius + glowRadius * bloom`) that spill further outward as brightness increases. At 200% brightness, the bloom radius doubles and the glow becomes intensely bright.

5. **Cursor cutout** — When cursor reveal is enabled, a radial gradient is drawn in `.destinationOut` blend mode centered on the cursor position. The gradient goes from fully opaque (punches through the glow) at the center to fully transparent at the edge, creating a feathered reveal circle.

### Animation System

All visual properties (brightness, color temperature, border width, top inset) use per-frame lerp interpolation at 60fps. When a target value changes, an animation timer fires and each displayed value moves 12% closer to its target per frame, settling in ~0.3 seconds. Timers run in `.common` run loop mode so animations continue during button hold interactions.

### Display Quality

- **Retina/HiDPI** — Core Graphics rendering automatically uses the window's backing scale factor, so all glow paths, gradients, and the cursor cutout render at full Retina resolution (2x–3x pixel density).
- **Wide-gamut color** — Gradients use the display's native color space (`NSScreen.colorSpace`) for accurate color reproduction on P3 displays (MacBook Pro, Studio Display, Pro Display XDR), with a fallback to device RGB.

### Window Architecture

The overlay window sits at a custom window level (just below or above the menu bar depending on mode), ignores all mouse events (`ignoresMouseEvents = true`), and is excluded from screen capture by default via `sharingType = .none` (togglable to `.readOnly` to make it visible in recordings). One overlay window is created per active monitor.

## Credits

- Original concept: [Scott Hanselman's EdgeLight](https://github.com/shanselman/EdgeLight)
- macOS implementation by [Richard Crane](https://inventingfirewith.ai)
