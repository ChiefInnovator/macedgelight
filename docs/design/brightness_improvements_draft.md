# Display brightness boost: improvements for MacEdgeLight 4.0.0

- **Author:** Richard Crane / project engineering
- **Status:** Revision 3. Applies the Goldfish review's recommendation to narrow scope. **Shipped in 3.1.0:** Phase 1 (strength, D1 = menu-only stepped submenu) and Phase 2 (conflict detection, D2 = every tick, D4 = A, keep writing and show the conflict; tracker, status resolver and harness checks are in existing files rather than new ones). **Removed from this design:** thermal/Low Power status (D3), the event log, the diagnostics report, and the known-app list; each needs its own design if wanted. Phase 2's go/no-go hardware run passed on the development Mac (no false conflicts in 30 s; separate-process writer detected within 10 s and cleared after it stopped); the external-EDR-display and thread-sanitizer runs were not done. The target release and the file table below predate this narrowing.
- **Date:** 2026-11-04
- **Target release:** 4.0.0 (next major version). Baseline: 3.0.4 source.
- **Context:** BrightIntosh (GPL-3.0) was read as a source review only (commit `f6806b8`, 2026-10-08; findings come from one reader and were not independently re-checked). No BrightIntosh code or constants are used; every threshold below was derived here from MacEdgeLight's own timings and harness.

## Current behavior (read this first)

Terms used in this document:

- **Ramp:** the table of 256 brightness values per color channel that the display uses to map pixel values to output. Boost writes a ramp that rises linearly from 0 to `gammaScale` (today a constant 1.55). A value above 1.0 pushes pixels into extended dynamic range.
- **Headroom:** how far above normal white macOS currently lets the display go (1.0 = none). *Live* headroom changes with conditions; *potential* headroom is a capability, not a safe limit.
- **EDR overlay:** an invisible, full-screen Metal layer that keeps an extended-range rendering context open so macOS grants headroom. It requests headroom equal to the live value, independent of the ramp.
- **Safe scale:** the ramp scale actually applied. It is `gammaScale` clamped to 90% of that display's live headroom, never below 1.0.
- **Maintenance tick:** a timer on the main run loop, every 0.5 seconds while boost is active. Each tick refreshes the display configuration, rebuilds stalled overlays, and writes a freshly generated ramp (it never reads the live table and rescales it).
- **Recovery:** a state machine (`BoostRecoveryState`) that suspends the renderer on sleep, lock, or session changes without clearing the saved preference, then resumes after a settle period (2 s after wake, 0.75 s after unlock). A manual off-then-on waits 30 s.
- **ColorSync restore:** deactivation calls `CGDisplayRestoreColorSyncSettings()` to return the user's profile.
- **HUD:** the floating control panel toolbar.

Today: one fixed strength; a failed ramp write is only logged; `EDRInfoWindow` (headroom, gamma deviation, copy button) appears only with a debugger attached.

## The Problem

1. **One fixed strength.** The ramp scale is a constant. A user who finds full boost too harsh can only turn it off. (This draft does not claim a strength control saves heat or battery: the EDR overlay requests the same headroom at any level, so only the ramp changes.)
2. **Silent conflicts (hypothesized, not yet reproduced).** If another tool also writes the gamma table, the two writers may fight, and the toggle would still say ON. We have no reproduction yet; the Phase 2 harness case produces one before any UI ships.
3. **No visibility into system limits.** The app never reads thermal state or Low Power Mode, so the user cannot tell why boost looks weak.
4. **No user-reachable diagnostics.** A user reporting "boost faded after wake" cannot attach headroom, ramp readback, or recent events.

## Overview

Four changes, delivered in three phases, each buildable and testable on its own. The default behavior of 3.0.4 is preserved: strength defaults to full, and boost continues to write during a suspected conflict.

BrightIntosh ideas considered and the MacEdgeLight position:

| Idea (observed) | Position |
|---|---|
| User strength slider | Adopt as a persisted level (Phase 1). |
| Detect repeated gamma resets by another tool | Adopt, with a corrected mechanism (Phase 2). |
| Name known conflicting apps | Reject (see Alternatives). |
| Capture the live table and scale it | Reject; conflicts with the fresh-ramp rule. |
| Per-model device tables | Reject; headroom gating already works without a model list. |
| Battery/adapter auto-off, timer, CLI, widget | Defer. |
| Network diagnostics upload | Reject. |

## Goals

1. Let the user choose boost strength without weakening any existing clamp.
2. Tell the user when another process appears to be changing the gamma table, and when macOS thermal or Low Power state is active. Goal 2's conflict part ships only if the Phase 2 go/no-go criteria are met.
3. Give the user a local, copyable diagnostics report.
4. Keep every invariant in `AGENTS.md`: fresh ramp, gamma only on the main thread, ColorSync restore on deactivate, idempotent start/stop, recovery stops first on shutdown.

## Non-Goals

- Copying BrightIntosh code or constants; private backlight APIs; network upload of diagnostics.
- Overriding macOS thermal or power limits, or promising constant or measured luminance.
- Changing the 30-second manual re-enable interval or `BoostRecoveryState` transition logic.
- A CLI, App Intents control, battery or adapter automation, a boost timer, and lid-closed handling (display-topology rebuild may already cover the lid case; it is untested). Each adds a control surface that must stay consistent with the persisted `edrBoosted` preference.
- Reducing heat or battery use.

## Technical Plan

### 1. Adjustable boost strength (Phase 1)

A persisted `boostLevel` from 0.1 to 1.0 (default 1.0). Level is applied against the *effective* ceiling, so the whole range is always usable:

`applied = 1.0 + level × (safeCeiling − 1.0)`, where `safeCeiling` is today's safe scale for that display (`gammaScale` clamped to 90% of that display's live headroom, floor 1.0).

- Level 1.0 reproduces 3.0.4 exactly. On a display with 1.3× live headroom, `safeCeiling` is 1.17 and the range 0.1–1.0 maps to 1.017–1.17, so there is no dead zone.
- The minimum is 0.1, not 0: turning boost off is the toggle's job, and "ON" never means "ON with no effect".
- The stored value is validated on load. A missing, non-finite, or out-of-range value becomes 1.0. Legacy installs have no stored key and therefore get 1.0.
- A level change applies immediately through a public method on `DisplayBrightnessManager` that rewrites the ramp on the main thread without rebuilding overlays. The manager receives the level by assignment from `EdgeLightManager`; it does not import `AppSettings`, so the hardware harness still compiles it standalone.
- `boostLevel` does not change `edrBoosted`, recovery state, or the EDR overlay.
- Ring-light reset leaves `boostLevel` unchanged (it already preserves boost state). The full reset to defaults restores 1.0 along with `edrBoosted = false`.

Control form: resolved as D1-C, a menu-only stepped submenu (10/25/50/75/100%), shipped in 3.1.0.

### 2. Conflict detection (Phase 2, gated)

**Mechanism.** At the start of each maintenance tick, before writing, read the display's live ramp and compare it with the last ramp this process wrote to that display. A difference means something changed the table after our last write. (A read taken after our own write would almost always match, because another tool writes in the gap between our writes. Reading first is what makes detection possible.) The read is for comparison only; nothing is rescaled from it, so the fresh-ramp rule holds.

- Sample count comes from the call (`CGDisplayGammaTableCapacity` and the returned count), not a hard-coded 256. A shared read function on `DisplayBrightnessManager` replaces the separate copies in `EDRInfoWindow.gammaDeviation` and `BoostHardwareCheck.gamma(for:)`.
- Comparison covers every sample of all three channels. Tolerance: 0.002 maximum absolute error per sample, the value `BoostHardwareCheck.checkRamp` already uses. Phase 2 validates it (see go/no-go).
- No comparison is made when there is no last-written ramp for that display, when the previous write failed, or inside the **grace period**: 3 seconds after activation, an overlay rebuild, any `resetGammaToProfile()`, or a recovery resume. These are the moments our own code or macOS legitimately changes the table.
- A failed write is never counted as a mismatch.

**Classification** (per display, time-based, independent of D2):

- `persistent` when at least 3 mismatching comparisons occur within any 6-second window. Counting within a window, not requiring consecutive ticks, so a tool that rewrites every other tick is still detected.
- Back to clear after 10 seconds with no mismatch.
- A single mismatch changes nothing visible. There is no `suspected` state.

**Behavior on `persistent`.** Boost keeps writing (the preference is not cleared and writing is not stopped) until the owner picks a mitigation (D4). The UI shows a distinct conflict state, described below. Without a mitigation the user's only remedy is the toggle, and the message says so.

**Go/no-go for Phase 2.** The feature ships only if the hardware harness shows all of: zero mismatches over 30 seconds of normal boost on the built-in display and on one external EDR display; `persistent` reached within 10 seconds when a *separate process* rewrites the table every 1 second; no `persistent` after that process stops, within 10 seconds. If the tolerance cannot satisfy these, record the measured numbers in `docs/SPEC.md` and drop conflict detection.

**Event log.** A small in-memory log (last 50 events, monotonic timestamps) records activate, deactivate, rebuild (with reason), recovery events, write failures (with `CGError`), conflict transitions, and thermal/power changes. It is created in Phase 2 so conflict transitions have somewhere to go, and read in Phase 3. It is lost on crash or relaunch; a report cannot cover an earlier run.

### 3. Thermal and Low Power status (Phase 3)

Notify-only by default (D3). The app registers for the thermal state change notification and the power-state change notification, on the main queue, and reads both once at start. Wording makes no causal claim:

- Thermal `.serious` or `.critical`: "System thermal state: serious" (or "critical").
- Low Power Mode on: "Low Power Mode is on".
- `.nominal` and `.fair` show nothing.

### 4. Status resolution and UI (Phases 2–3)

One pure function resolves what the user sees. Precedence, highest first: **waiting** (recovery or 30-second interval) → **conflict** → **thermal** → **Low Power**. Only the winning message is shown; every active condition appears in the diagnostics report.

| State | Menu title | HUD button | Tooltip / accessibility |
|---|---|---|---|
| Waiting (unchanged) | Display Brightness Boost — WAITING | hourglass | existing countdown text |
| Conflict | Display Brightness Boost — CONFLICT | `exclamationmark.triangle` | "Another app appears to be changing display gamma. Turn boost off to stop." |
| Thermal / Low Power | unchanged (ON) | unchanged | status text as tooltip and accessibility value only |

The menu and HUD currently treat any non-nil recovery message as WAITING; both are updated to use the resolved state.

### 5. Diagnostics report (Phase 3)

The report text is built by one shared function, and `EDRInfoWindow` calls it instead of building its text inline. The debug window keeps its existing backlight line (which calls a private API); that line stays in the debug window and is not part of the shared function or the user-facing copy item.

Contents: app version, macOS version, hardware model; per display (ID, built-in or external, live and potential headroom, safe ceiling, applied scale, last write result, conflict state, ramp deviation); settings (`edrBoosted`, `boostLevel`); recovery flags; thermal and Low Power state; the event log. It excludes running-app names and display serials. A menu item "Copy Boost Diagnostics" puts it on the clipboard, which other apps can read.

### Data flow

```
 boostLevel ──► EdgeLightManager ──► DisplayBrightnessManager (level assigned)
                                        │ each tick:
                                        │  1. read live ramp, compare to last written (outside grace)
                                        │  2. applied = 1 + level × (safeCeiling − 1)
                                        │  3. write fresh ramp, remember it, log failures
                                        ▼
                     conflict tracker ─► event log
                                        ▼
 thermal / power notifications ───────► status resolver ──► menu, HUD
 recovery message ────────────────────►
```

## Alternatives Considered

| Alternative | Why not |
|---|---|
| Read back immediately after our own write | A competing tool writes between our writes, so the read almost always matches. It would only flag our own quantization. |
| Capture the live table once and scale it (BrightIntosh) | Stores whatever another tool or Night Shift had set and restores it as the user's profile. Violates the fresh-ramp rule. GPL code. |
| Compare only the last ramp entry | A partial reset with the same endpoint goes unseen; full comparison costs little more. |
| Consecutive-mismatch rule | A writer that fires every other tick resets the counter and is never detected. A windowed count is used. |
| Stop boosting on persistent conflict | Leaves the user with no boost and no explanation while the other tool keeps the table. Left to D4. |
| Name known conflicting apps by bundle ID | Adds a file that goes stale and a process scan; the readback is the real signal and the message does not need a name. |
| Level scales against the 1.55 constant | The 90%-of-headroom clamp then flattens most of the slider on low-headroom displays. |
| Level 0 allowed | "ON" with no effect; the overlay still runs. |
| Device whitelist with per-model constants | Goes stale on new hardware; the capability check plus live-headroom clamp needs no list. |
| Upload diagnostics | New privacy surface and network dependency. |
| Ring buffer persisted to disk | New storage and cleanup for a utility that stores only preferences. |

## Risks

- **Quantization false positives.** Drivers may round the table. The go/no-go criteria above decide whether item 2 ships.
- **Our own writes look like conflicts** after rebuild, wake, or reset. The grace period covers known cases; the harness sweeps rebuild and wake-resume to find others.
- **Main-thread cost.** One extra table read (three channels) per display per tick. Measured in the two-hour acceptance run; if CPU rises by more than 1 percentage point over the 3.0.4 baseline, D2-B (every fourth tick) applies.
- **Two "brightness" controls** (ring light and boost) can confuse users. The strength control is labeled "Boost strength" and is separate from Cmd+Shift+Up/Down.
- **Thermal wording** states a state, not a cause, to stay within the "no luminance promise" rule.
- **Event log is in-memory only.**

## Open Decisions (owner chooses; not ranked)

**D1. Strength control form** (resolved: C, shipped in 3.1.0)
- **A. Slider** in the HUD and menu. Fails when the HUD becomes crowded or the slider is hard to use with VoiceOver.
- **B. Stepped control** (for example 25%, 50%, 75%, 100%) with two new hotkeys. Fails when users want in-between values, or the chosen hotkeys collide (currently only Q and Cmd+Shift+L/Up/Down/B are used).
- **C. Menu-only submenu.** Fails when HUD users never find it.

**D2. Readback frequency**
- **A. Every tick (0.5 s).** Fastest detection; costs one read per display per tick.
- **B. Every fourth tick (2 s).** Cheaper; detection takes up to about 6 seconds longer, and 3 mismatches in 6 seconds becomes the minimum, so a 2-second sample sees at most 3 samples in the window.

**D3. Thermal response**
- **A. Notify only.** The live-headroom clamp is assumed to follow macOS reductions; this is not yet measured. Phase 3 measures headroom at `.serious` before choosing B.
- **B. Notify and lower the applied scale** at `.serious`/`.critical`. Fails when it duplicates the clamp and delays recovery.

**D4. Behavior during a persistent conflict**
- **A. Keep writing, show the conflict.** Matches 3.0.4; flicker may continue.
- **B. Back off to one write every 5 seconds** while `persistent`. Reduces flicker; slows repair after a legitimate reset.
- **C. Add a "Pause boost" action** that suspends writing without clearing `edrBoosted`. Needs a new state in recovery handling.

**D5. Scope for 4.0.0**
- **A. All three phases.**
- **B. Phase 1 only;** Phases 2–3 get separate designs once a conflict is reproduced.
- **C. Phases 1 and 3;** skip conflict detection.

## Detailed Implementation

Phase column: P1 strength, P2 conflict and event log, P3 thermal, status, diagnostics, P0 release. All paths are relative to the repository root.

| Phase | Action | File | What changes and why |
|---|---|---|---|
| P1 | Modify | `MacEdgeLight/AppSettings.swift` | Add `boostLevel` (key string `boostLevel`), registered default 1.0, validated on load (missing, non-finite, outside 0.1–1.0 → 1.0), clamped on set. `resetToDefaults()` sets it to 1.0. |
| P1 | Modify | `MacEdgeLight/DisplayBrightnessManager.swift` | Add settable `boostLevel` (default 1.0); pure static function turning level and safe ceiling into the applied scale; `refreshGamma` uses it; public method to apply a level change now on the main thread. |
| P1 | Modify | `MacEdgeLight/EdgeLightManager.swift` | Observe `AppSettings.boostLevel` via the existing settings change path, assign it to the manager, call the apply method. `resetToDefaults()` resets it. `resetRingLight()` leaves it alone. |
| P1 | Modify | `MacEdgeLight/StatusBarController.swift`, `MacEdgeLight/ControlPanelWindow.swift` | Strength control: menu-only stepped submenu (D1-C, shipped). Label "Boost strength". Disabled with the boost button when no EDR display and boost off. |
| P1 | Modify | `MacEdgeLight/HotkeyManager.swift` | Not needed: D1 resolved as menu-only, so no new hotkeys. |
| P1 | Modify | `MacEdgeLightTests/SafeGammaScaleTests.swift` | Add: level 1.0 equals today's safe scale; level 0.1 at ceiling 1.55 gives 1.055; at ceiling 1.17 the range is 1.017–1.17; ceiling 1.0 gives 1.0 at any level; monotonic in level; NaN level or ceiling gives 1.0. |
| P1 | Modify | `MacEdgeLightTests/AppSettingsTests.swift` | Add `boostLevel` to `SettingsSnapshot` capture/restore (otherwise tests leak into `UserDefaults`); test default, missing key → 1.0, out-of-range and NaN → 1.0, persistence round trip, full reset → 1.0, ring-light reset leaves it. |
| P2 | Create | `MacEdgeLight/BoostConflictTracker.swift` | Pure value type, injected monotonic time. Input: per-display comparison result (match, mismatch, skipped) and timestamp. Output: clear or persistent. 6-second window, 3 mismatches, 10-second clear, 3-second grace restarted by events from the manager. No AppKit. |
| P2 | Create | `MacEdgeLight/BoostEventLog.swift` | 50-entry in-memory log with monotonic timestamps; event enum for the events listed in Technical Plan §2. |
| P2 | Modify | `MacEdgeLight/DisplayBrightnessManager.swift` | Add shared ramp read function (sample count from the API); remember last written ramp per display (main thread); compare before write outside grace; feed tracker and log; expose a read-only per-display status snapshot. Restart grace on activation, rebuild, reset, and resume. |
| P2 | Create | `MacEdgeLight/BoostStatus.swift` | Pure resolver: inputs waiting message, conflict flag, thermal state, Low Power flag; output the winning state with the table strings above. |
| P2 | Modify | `MacEdgeLight/EdgeLightManager.swift` | Replace the recovery-message-only path with the resolved status; both consumers read it. `BoostRecoveryState` logic is unchanged. Feed recovery events to the log. |
| P2 | Modify | `MacEdgeLight/StatusBarController.swift`, `MacEdgeLight/ControlPanelWindow.swift` | Handle the conflict state (menu title, `exclamationmark.triangle`, tooltip, accessibility value) distinct from WAITING. Blocked on D4 for any added action. |
| P2 | Modify | `MacEdgeLight/EDRInfoWindow.swift` | `gammaDeviation` uses the shared read function. |
| P2 | Create | `MacEdgeLightTests/BoostConflictTrackerTests.swift` | Worked cases at 0.5 s ticks: 3 mismatches in 6 s → persistent; alternating match/mismatch (mismatch at 0, 1, 2 s) → persistent; 2 mismatches in 6 s → clear; mismatch during grace ignored; failed write not counted; 10 s clean clears; per-display independence; same cases at 2 s sampling (D2-B). |
| P2 | Create | `MacEdgeLightTests/BoostStatusTests.swift` | Precedence for every combination of the four conditions; conflict never reported as WAITING; recovery never clears `edrBoosted`. |
| P2 | Modify | `MacEdgeLightTests/BoostRecoveryTests.swift` | Add one test that conflict state does not alter any recovery transition. Existing 24-ordering tests unchanged. |
| P2 | Create | `scripts/GammaWriter.swift` | Separate-process helper that rewrites a display's ramp every 1 second for N seconds, then restores ColorSync. |
| P2 | Modify | `scripts/BoostHardwareCheck.swift` | Reuse `gamma(for:)` and `resetGammaAndVerifyChange`; add the three go/no-go checks and a level sweep (0.1, 0.5, 1.0) comparing readback with the expected applied scale at the measured live headroom. |
| P2 | Modify | `scripts/test-boost-hardware.sh` | Add the new manager dependencies (`BoostConflictTracker.swift`, `BoostEventLog.swift`) to the `swiftc` line; compile and launch `GammaWriter`. Run with MacEdgeLight quit. |
| P3 | Create | `MacEdgeLight/BoostDiagnosticsReport.swift` | Shared report builder as described in Technical Plan §5; no private API calls. |
| P3 | Modify | `MacEdgeLight/EDRInfoWindow.swift` | Use the shared builder for its text; keep its own backlight line. |
| P3 | Modify | `MacEdgeLight/EdgeLightManager.swift` | Register thermal and power-state observers on the main queue at start; read both once; remove them with the other observers in `stop()`, keeping the existing order (recovery stops first, observers last). |
| P3 | Modify | `MacEdgeLight/StatusBarController.swift` | "Copy Boost Diagnostics" item. |
| P3 | Create | `MacEdgeLightTests/BoostDiagnosticsReportTests.swift` | Contains no running-app names or serials; event log capped at 50 and ordered; includes thermal and Low Power state. |
| P1–P3 | Modify | `MacEdgeLight.xcodeproj/project.pbxproj` | Add each new file to the correct target by hand (the test-target script only creates the target once). |
| P1–P3 | Modify | `docs/SPEC.md` | Update XDR Brightness Boost (level formula, Constants, Lifecycle, conflict, Regression Checks), Settings, EDR Diagnostics Window, Global Hotkeys (if D1 = B), architecture tree, File Manifest. |
| P1–P3 | Modify | `README.md` | Document strength, conflict message, diagnostics copy. State that conflict detection is a heuristic and strength values are gamma-scale values, not measured luminance. |
| P1–P3 | Modify | `AGENTS.md`, `CLAUDE.md` | Add new files to the architecture lists. Add invariants: conflict detection never clears the preference, and diagnostics never leave the machine. |
| P0 | Modify | `MacEdgeLight.xcodeproj/project.pbxproj` | `MARKETING_VERSION` to 4.0.0. |
| P0 | Create | `docs/RELEASE_NOTES_4.0.0.md` | Release notes; preserve earlier notes. |
| P0 | Modify | `docs/index.html`, `docs/llms.txt`, `docs/sitemap.xml` | Run `make sync-site-version`, then `make check-site-version`; the site must show the full `4.0.0`. |

### Phasing and end states

1. **P1:** strength works end to end with default 1.0; `make test` passes; no new type depends on later phases.
2. **P2:** conflict detection and event log; harness go/no-go decides whether the UI ships. If it fails, remove tracker UI and keep the shared read function.
3. **P3:** thermal/Low Power status and diagnostics. D3-A needs the `.serious` headroom measurement before any scale reduction.

Each phase is its own feature branch off `develop`; release follows the existing `develop` → `main` flow.

### Verification

- `make test` after each phase; `make build` for a deliverable debug app.
- `bash scripts/test-boost-hardware.sh` and `bash scripts/test-boost-hardware.sh --thread-sanitizer` with MacEdgeLight quit. Pass criteria are the P2 go/no-go list plus level-sweep readback within 0.002 of the expected scale.
- Manual conflict check: run `GammaWriter` against the display while boost is on; the conflict state appears within 10 seconds and clears within 10 seconds of stopping it.
- Acceptance run: 10 sleep/wake and lock/unlock cycles, then two hours of normal use; record CPU change against 3.0.4 (limit: +1 percentage point), conflict false positives (limit: zero), and write failures.
- Readback does not prove physical luminance; no strength value is described as a measured brightness change.
