# MacEdgeLight

A macOS menu bar utility that renders an ambient glowing border around the screen. Pure Swift/AppKit, no SwiftUI.

## Build

```bash
make build       # Debug build
make release     # DMG + zip for distribution
make clean       # Clean build artifacts
```

Or open `MacEdgeLight.xcodeproj` in Xcode. No sandbox entitlements (needed for overlay windows and desktop icon control).

## Architecture

- **AppSettings** — Singleton, `@Published` properties persisted to UserDefaults
- **EdgeLightManager** — Central controller wiring settings to overlays, control panel, status bar, and hotkeys
- **MonitorManager** — Creates/manages one `EdgeLightOverlayWindow` per screen
- **EdgeLightOverlayWindow** — Borderless, click-through, capture-excludable overlay; hosts `EdgeLightView`
- **EdgeLightView** — Core Graphics drawing: outer glow, gradient frame, inner glow, bloom, cursor cutout. Uses lerp-based animation timer on `.common` run loop mode
- **ControlPanelWindow** — Floating HUD toolbar (NSPanel). Uses `RepeatButton` for hold-to-repeat and `DoubleClickButton` for lightbulb reset
- **StatusBarController** — Menu bar icon and dropdown menu
- **HotkeyManager** — Global keyboard shortcuts (Cmd+Shift+L/Up/Down)
- **LoginItemManager** — Launch-at-login via SMAppService
- **DisplayBrightnessManager** — XDR brightness boost via invisible Metal EDR overlay (alpha=0, headroom signaling) + linear gamma table scaling (1.45x). Constants: `maxHeadroomCap`, `gammaScale`. Boost is force-disabled on `willSleep`/`didWake` (observed in `EdgeLightManager`) — restoring across sleep is unreliable since headroom vanishes while the boosted gamma LUT stays live.
- **MagnifierWindow** — Floating magnifier loupe following cursor
- **EDRInfoWindow** — Debug-only floating diagnostics panel (appears when debugger attached). Shows live EDR headroom, gamma deviation, color space, external EDR detection. Copy button in titlebar.

## Key conventions

- All timers use `RunLoop.current.add(timer, forMode: .common)` (not `Timer.scheduledTimer`) so they fire during event tracking (e.g., button holds)
- Control panel window level is `mainMenu + 2` to stay above the overlay
- Settings changes flow: AppSettings -> EdgeLightManager -> MonitorManager -> applySettingsToAll() -> EdgeLightOverlayWindow.applySettings()
- Visual transitions are animated via per-frame lerp in EdgeLightView.animationTick()
- Menu bar mode is tri-state (0=below, 1=extend, 2=auto). Auto mode tracks cursor at 30fps and animates topInset.
- Control panel buttons are split into light-dependent (dimmed when off) and always-active groups, separated by a vertical divider
- EdgeLightView.snapToCurrentValues() is called on startup to avoid a visible flash when saved state is "off"
- License: PolyForm Strict 1.0.0 (noncommercial use, no redistribution or modification)
- Full technical spec in docs/SPEC.md
