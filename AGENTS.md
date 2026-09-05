# MacEdgeLight Agent Guide

Repository instructions for Codex. Keep this guide aligned with the implementation and `docs/SPEC.md`; `CLAUDE.md` provides companion guidance for Claude Code.

## Working Rules

- Keep changes focused on the requested task and preserve existing uncommitted work.
- Leave no untracked files: stage new project files and explicitly ignore local/generated files. Check `git ls-files --others --exclude-standard` before finishing; do not hide source files with ignore rules.
- Never run `git rebase`. If branches diverge, stop and ask.
- Do not add `Co-Authored-By` or AI-attribution lines to commits.
- Verify behavior with appropriate checks and distinguish automated results from untested hardware behavior.

## Project Overview

MacEdgeLight is a native macOS menu bar utility that renders an ambient glowing border around the screen. It is written in Swift/AppKit with no SwiftUI.

## Build And Test

```bash
make build       # Debug build
make test        # Unit tests
make release     # Signed/notarized DMG + zip for distribution
make clean       # Clean build artifacts
```

You can also open `MacEdgeLight.xcodeproj` in Xcode.

Automatic signing uses the MILL5 team (`FS6453639M`) and registered App ID `com.richardcrane.macedgelight`. Keep Hardened Runtime enabled. Releases use Xcode account authentication; `make package` packages an already notarized Organizer export in `build/export/`. See README for the release workflow.

The app intentionally does not use sandbox entitlements because overlay windows and desktop icon control require broader macOS access.

## Architecture

- `AppSettings` — Singleton with `@Published` UserDefaults-backed settings.
- `EdgeLightManager` — Central controller wiring settings to overlays, control panel, status bar, hotkeys, and system lifecycle notifications.
- `BoostRecoveryState` — Value type in `EdgeLightManager.swift`; typed lifecycle events, suspension state, and recovery eligibility.
- `MonitorManager` — Creates and manages one `EdgeLightOverlayWindow` per selected screen.
- `EdgeLightOverlayWindow` — Borderless, click-through, capture-excludable overlay hosting `EdgeLightView`.
- `EdgeLightView` — Core Graphics drawing for outer glow, gradient frame, inner glow, bloom, and cursor cutout; uses a `.common` run loop animation timer.
- `ControlPanelWindow` — Floating AppKit HUD toolbar with `RepeatButton` for hold-to-repeat and `DoubleClickButton` for lightbulb reset.
- `StatusBarController` — Menu bar icon and dropdown menu.
- `HotkeyManager` — Global keyboard shortcuts: Cmd+Shift+L toggles light, Cmd+Shift+Up/Down adjusts brightness, Cmd+Shift+B toggles XDR boost, and five rapid unmodified `Q` taps panic-quit.
- `LoginItemManager` — Launch-at-login via `SMAppService`.
- `DisplayBrightnessManager` — XDR brightness boost using an invisible Metal EDR overlay plus a synthetic linear gamma ramp.
- `MagnifierWindow` — Floating magnifier loupe following cursor.
- `EDRInfoWindow` — Debug-only panel shown when a debugger is attached; live headroom, gamma deviation, color-space diagnostics, and a copy button.

## Display Brightness Boost Notes

`DisplayBrightnessManager` is safety-critical. Be careful with gamma, sleep/wake, lock/unlock, and display-change paths.

- `applyGammaScale` must generate a fresh ramp via `buildBoostedRamp`; do not read and rescale the live LUT.
- Deactivation must call `CGDisplayRestoreColorSyncSettings()` through `resetGammaToProfile` to restore the user’s ColorSync profile.
- While boost is active, Night Shift, True Tone, and hardware calibration are bypassed by the synthetic ramp and return when boost deactivates.
- `settings.edrBoosted` is the persisted user preference; `isBoosted` is active renderer state. Toggle the preference, not temporary renderer state. Controls must allow turning the preference off while recovery is pending or a display is unavailable.
- Route system sleep/wake, display sleep/wake, lock/unlock, and user-session changes through `BoostRecoveryState.handle(_:now:)`. Suspend without clearing the preference.
- A manual off transition from active boost starts a 30-second reactivation interval. Re-enabling queues recovery; turning off while waiting cancels without extending the interval. Keep waiting UI distinct from active rendering. This is an observed-timing workaround, not an Apple guarantee.
- Recovery checks every 0.5 seconds without a retry limit. Require an enabled preference, available display, running manager, awake displays/system, and an active, usable, unlocked user session. Sample `CGSessionCopyCurrentDictionary` during recovery; stale session data must not undo a suspension notification.
- System/display wake settles for 2 seconds; unlock/session activation settles for 0.75 seconds. Use monotonic uptime, and never shorten an existing settle deadline when events overlap.
- Start/stop and `DisplayBrightnessManager.setEnabled(_:)` are idempotent. Stop recovery before other termination cleanup so boost cannot reactivate after shutdown or a manual toggle off.
- Gamma maintenance reasserts a freshly generated ramp every 0.5 seconds, even if headroom is unchanged, and retries failed writes. Each display uses its own current headroom. Preserve the neutral floor of 1.0 and existing safety clamp; potential headroom is a capability indicator, not a safe rendering limit.
- AppKit and gamma operations belong on the main thread. Render targets are keyed by display ID; protect shared snapshots with `renderLock`, and never hold it while `nextDrawable()` can block. Old callbacks must not update removed or replacement layers.
- Rebuild overlays for topology changes or stalled submissions, not ordinary headroom notifications. Keep EDR contexts alive while updating headroom.
- Actual logout terminates the app; automatic restoration requires Launch at Login. Do not promise constant physical luminance or boost on the login window, and do not override macOS thermal/power limits.

## Key Conventions

- Use AppKit, not SwiftUI.
- All timers should be added to `.common` run loop mode where they need to fire during event tracking.
- Keep the control panel at `mainMenu + 2`, above the ring-light overlay.
- Settings flow is `AppSettings` → `EdgeLightManager` → `MonitorManager.applySettingsToAll()` → `EdgeLightOverlayWindow.applySettings()`.
- Visual transitions are animated via per-frame lerp in `EdgeLightView.animationTick()`.
- Menu bar mode is tri-state: `0 = below`, `1 = extend`, `2 = auto`. Auto mode tracks the cursor at 30 fps and animates the top inset.
- Preserve the control panel's light-dependent and always-active button groups. Resetting the ring light must preserve boost, magnifier, and desktop-icon state.
- Call `EdgeLightView.snapToCurrentValues()` on startup to avoid visible flashes from persisted off-state.
- Do not add private hardware backlight manipulation for the XDR boost; the current implementation intentionally uses gamma plus EDR headroom signaling only.

## Testing Guidance

- Run `make test` after Swift changes when practical, and `make build` for a deliverable debug app.
- Tests cover settings persistence, panic tap detection, gamma ramp/clamp behavior, and recovery transitions. Test the production event handler when changing lifecycle behavior, including event order, delayed availability, repeated cycles, and cancellation.
- Live display checks: `bash scripts/test-boost-hardware.sh`; add `--thread-sanitizer` to check the rendering path for races. Quit MacEdgeLight first to avoid competing gamma writers. The harness temporarily changes display gamma without changing saved app preferences, and restores ColorSync on completion, caught failure, or ordinary SIGINT/SIGTERM cancellation.
- Hardware readback checks do not prove physical brightness or real sleep/logout behavior. Use the manual acceptance checklist in `docs/SPEC.md` for sleep/wake, lock/unlock, login, display reconnection, and sustained use.

## Documentation

- Always show the full `major.minor.patch` version on the GitHub Page, including visible labels, metadata, structured data, and download links. Xcode `MARKETING_VERSION` is authoritative. After version changes run `make sync-site-version`, then `make check-site-version`. Preserve historical release note versions.

- Keep `docs/SPEC.md` aligned with implementation changes.
- Keep README feature claims accurate, especially around XDR brightness boost behavior.
- Avoid documenting behavior that depends on removed/private APIs unless the code actually uses it.

## License

The project uses PolyForm Strict 1.0.0. Do not add or change license headers unless explicitly requested.
