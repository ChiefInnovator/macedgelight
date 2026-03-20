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
- Toggle whether the light extends over or sits below the macOS menu bar
- When below, the frame shifts down cleanly (no clipping)

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
| Menu bar | Extend over menu bar | |
| Circle | Cursor reveal mode | Filled when on |
| Video | Show in screen capture | Filled when on |
| Eye | Hide desktop icons | Swaps to eye.slash |
| Reset | Reset all settings to defaults | |
| X | Quit | |

## Requirements

- macOS 13 Ventura or later

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

The edge light is drawn using Core Graphics with multiple layered glow passes:

1. **Outer glow** — concentric expanding rectangles with decreasing opacity
2. **Solid frame** — gradient fill from corner to corner (white → tinted → white)
3. **Inner glow** — soft light bleeding inward from the frame edge
4. **Bloom** — additive `.plusLighter` compositing for brightness above 100%
5. **Cursor cutout** — `.destinationOut` radial gradient to punch through the glow

The overlay window sits at a custom window level (just below or above the menu bar), ignores all mouse events, and is excluded from screen capture by default via `sharingType = .none` (togglable to `.readOnly` to make it visible in recordings).

## Credits

- Original concept: [Scott Hanselman's EdgeLight](https://github.com/shanselman/EdgeLight)
- macOS implementation by Richard Crane
