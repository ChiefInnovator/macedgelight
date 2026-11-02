# MacEdgeLight: current architecture and focused interaction repairs

- **Author:** Richard Crane / project engineering
- **Status:** Fresh Goldfish review completed; accepted findings incorporated for implementation
- **Date:** 2026-11-02
- **Baseline:** Xcode marketing version 3.0.3; local source inspection, not a release or hardware certification

## Overview

MacEdgeLight is a native macOS 13+ menu bar utility built with Swift and AppKit. It has two independent functions: a visible screen ring light and a display brightness boost on EDR-capable displays. A floating HUD, menu, and global shortcuts control both. A magnifier, cursor cutout, and desktop-icon control support presentation and readability tasks.

This design records the whole product as implemented and proposes small repairs where source behavior contradicts existing user-facing promises. It preserves the AppKit HUD and existing rendering architecture. It also records the requested project-local EGM/Impeccable workflow and protected branch contract. The owner authorized uninterrupted drafting, fresh review, documentation, and implementation; this explicit sequence governs progression instead of pausing for each section.

[EGM](https://github.com/google/elephant-goldfish-model) is Google’s Elephant-Goldfish Model: the drafting agent keeps project context, while Goldfish reviewers receive fresh contexts and evaluate the written design. [Impeccable](https://github.com/pbakaus/impeccable) records product/visual context and reviews interface quality. Reports live beside this draft.

## The Problem

Source inspection exposes these concrete gaps. Locations describe the pre-change baseline and may move during implementation:

1. **Holding adjustment buttons cannot perform the documented fine adjustment.** `MacEdgeLight/ControlPanelWindow.swift:159-168` constructs a double-click bulb or an ordinary `NSButton`; it has no `RepeatButton`. The six fine-step manager methods already exist at `EdgeLightManager.swift:218-266`. README's feature list and SPEC's Button Types describe hold-to-repeat. This is a lost existing interaction, not a proposed new feature.
2. **Auto menu-bar reveal can react to a cursor on a display above its own display.** `EdgeLightOverlayWindow.swift:123-125` checks a lower Y bound and horizontal bounds but no upper Y bound. With vertically stacked displays sharing an X range, the lower display can retract its light for activity on the upper display.
3. **The help dialog omits implemented shortcuts.** `StatusBarController.swift:150-165` lists ring-light toggle and brightness adjustment but omits Cmd+Shift+B and the five unmodified Q taps within two seconds implemented in `HotkeyManager.swift:68-95`.
4. **Toolbar backdrop documentation may be stale.** The setup backdrop is white 0.1 / alpha 0.95, but `ControlPanelWindow.swift:363-369` replaces that with an alpha as low as zero when the light is on and thin. At default border 60 and brightness 1, alpha becomes 0.16. SPEC's Baseline Background says a dark baseline remains and glow can increase it. This arithmetic is verified, but NSVisualEffectView HUD material also supplies a backdrop. There is no rendered evidence of inadequate contrast. Preserve the incumbent appearance; assess visual readability before considering any opacity change.
5. **Accessibility identity is incomplete for action buttons.** Boolean toggles receive explicit labels/values in `ControlPanelWindow.swift:379-394`, while step/reset/hide buttons rely on their image descriptions and tooltips. Menu-bar cycling updates its value but lacks an explicit stable label. Explicit action names avoid depending on SF Symbol inference. This is a source-level gap, not a claim that VoiceOver is proven unusable.
6. **SPEC contains stale implementation claims.** Its control list includes launch/quit rather than the actual toolbar's reset/hide; hotkeys are described as Carbon registration although implementation uses NSEvent monitors with Carbon key-code constants; hold repetition is documented but missing; the screen-change description says always recreate while `MonitorManager` preserves overlays when IDs are unchanged. Correct these descriptions alongside the repairs.

## Goals

- Restore coarse single-click and fine hold adjustment for brightness, warmth, and border width, with existing clamps and directions.
- Restrict Auto reveal to the overlay's own screen menu-bar region, including stacked and negatively positioned displays.
- Preserve the incumbent HUD backdrop and add explicit accessible names/state without changing layout, feature groups, or symbol vocabulary.
- Make in-app help describe every implemented shortcut and accurately distinguish ring-light brightness from display boost.
- Keep gamma, rendering, recovery, capture, reset, and persisted-preference contracts unchanged.
- Record a complete current-product design and a source-derived Impeccable design system, with evidence limits stated.
- Enforce the requested same-repository PR sources: `feature/<name>` → `develop` → `main`, with required PRs/checks and no bypass.

## Non-Goals

- No SwiftUI migration, new settings architecture, new UI surface, onboarding, telemetry, subscription, or account system.
- No gamma tuning, private backlight writes, timing changes to recovery, or claims of fixed physical luminance.
- No changed capture APIs, magnifier redesign, desktop-icon process refactor, keyboard-event registration rewrite, or permission onboarding in this pass.
- No marketing-site redesign, version bump, release publication, notarization, deployment, or promotion campaign.
- No claim that source review or unit tests prove physical sleep/wake, VoiceOver experience, real capture exclusion, or sustained display behavior.

## Current Product and Architecture

### Application and settings

`MacEdgeLightApp.swift` runs `NSApplication` with an accessory activation policy and an `AppDelegate`. Launch creates and starts `EdgeLightManager`; termination stops it before restoring normally hidden Finder icons. There is no Dock-oriented primary window. `Info.plist` also declares the menu-bar application identity.

`AppSettings.swift` owns a singleton `ObservableObject`. Published properties persist immediately to standard UserDefaults. Defaults are ring light on, brightness 1.0, warmth 0.5, border 60 pt, Auto menu-bar mode, toolbar shown, single-monitor index 0, and boost/magnifier/cursor reveal/capture visibility/desktop hiding/login disabled. Manager actions clamp brightness to 0.2–2.0, warmth to 0–1, and border to 10–150 pt. Direct property assignments themselves are not validated. Existing migration code translates the old menu-bar Bool; migration behavior is outside this repair.

```text
HUD / menu / keyboard
        → EdgeLightManager → AppSettings → UserDefaults
        → MonitorManager → EdgeLightOverlayWindow[] → EdgeLightView
        → magnifier / Finder desktop control / login registration
        → boost eligibility → DisplayBrightnessManager
```

### Ring-light rendering and monitors

`MonitorManager.swift` creates one overlay for the selected screen or one per screen when All Monitors is on. It validates the selected index on screen changes. When display IDs are unchanged it resizes existing windows; topology changes recreate them. Initial settings are applied before `snapToCurrentValues()` to prevent persisted-off startup flashes.

`EdgeLightOverlayWindow.swift` owns borderless transparent, mouse-ignoring windows across Spaces. Capture visibility switches `sharingType` between `.none` and `.readOnly`; actual recorder behavior is system/app dependent. Below mode uses `mainMenu - 1`; Extend/Auto use `mainMenu + 1`. Auto samples cursor location at 30 Hz; optional cursor reveal samples at 60 Hz. Both use common run-loop modes.

`EdgeLightView.swift` draws an outer glow, diagonal white/tinted frame, inner glow, additive bloom above ring-light brightness 1.0, and optional feathered destination-out cursor cutout. Coordinates use points and AppKit backing scale. Color temperature interpolates cool to warm. Brightness, temperature, top inset, and border thickness converge using a 0.12 per-frame interpolation on a common-mode 60 Hz timer; the timer stops on settlement. Physical light output is not measured by these values.

### Controls and supporting windows

`ControlPanelWindow.swift` is a nonactivating 52 pt HUD with 44 pt icon buttons, 4 pt spacing, rounded corners, a thin divider, a drag grip, tooltips, and auto-hide. It sits at `mainMenu + 2`. Eleven ring-dependent controls precede the bulb; bulb, boost, magnifier, desktop icons, reset, and hide remain usable independently of ring-light state. Double-click bulb restores only ring settings, preserving independent tools and capture visibility. Reset to Defaults is broader and turns boost/magnifier off, restores hidden desktop icons, and resets capture visibility; it does not reset monitor, toolbar visibility, or login registration.

`StatusBarController.swift` creates the native menu, exposes ON/OFF/checkmarks, disables ring-dependent commands, and asynchronously refreshes after published settings setters finish. Opening the menu resynchronizes launch registration. Boost waiting is represented separately from saved intent and remains cancellable. `HotkeyManager.swift` uses local/global NSEvent key-down monitors, Carbon key-code constants, and a pure rolling tap detector. Global-monitor availability/permissions have not been validated by this design review.

`LoginItemManager.swift` registers `SMAppService.mainApp` and reconciles the setting to actual enabled status after requests. An approval-pending registration appears disabled; no approval-specific flow is added here. `MagnifierWindow.swift` captures screen content below its own window at 30 Hz and follows the cursor with a 2× loupe. Capture coordinates and permissions deserve separate multi-display validation; this pass does not claim they are proven. `EDRInfoWindow.swift` appears only under a debugger, displays headroom/gamma/color diagnostics, and offers timestamped clipboard output. It reads hardware brightness using a private getter; it does not write backlight settings.

### Brightness boost and lifecycle invariants

`DisplayBrightnessManager.swift` creates transparent Metal EDR signaling windows only on compatible screens. Capability comes from potential EDR headroom; rendering/gamma limits come from current headroom. Gamma uses fresh synthetic linear ramps, capped at 1.55 and 90% of each display’s current headroom, with a neutral floor of 1.0. Deactivation restores ColorSync, rather than retaining a sampled live LUT. While active, the ramp bypasses normal color response such as Night Shift and True Tone.

Main-thread maintenance every 0.5 seconds reapplies gamma, retries failed writes, refreshes topology/headroom, and rebuilds stalled contexts. Display-link rendering snapshots targets under `renderLock`, renders without holding that lock over `nextDrawable()`, and checks layer identity before updating health. A separate frame lock prevents overlapping render passes. No ordinary headroom-only notification should rebuild EDR contexts.

`BoostRecoveryState` in `EdgeLightManager.swift` separates persisted intent from active renderer state. Sleep/display sleep/lock/inactive session suspend immediately. Wake settles for 2 seconds; unlock/session activation for 0.75 seconds; overlapping deadlines never shorten. Recovery checks every 0.5 seconds without retry exhaustion and requires running, available, awake, active, usable, unlocked state. A manual active-off starts the observed 30-second reactivation interval; cancelling a queued request does not restart it. Stop cancels recovery before renderer cleanup. Logout terminates the app, so later automatic restoration depends on Launch at Login. None of these mechanisms establish physical luminance or override thermal/power limits.

### Build, website, tests, and delivery

`Makefile` delegates Debug build and unit tests to Xcode. Release export/notarization uses the configured Xcode account and MILL5 signing team with Hardened Runtime. Packaging checks matching bundle version, signature, stapled ticket, and Gatekeeper assessment. `scripts/sync-site-version.py` reads the authoritative Xcode marketing version and updates/checks README, homepage, and llms.txt; release notes stay historical. `site-version.yml` exposes `check-version` and uses a pinned checkout action.

The four current XCTest files cover settings persistence/reset/menu/toolbar state, recovery event ordering and cancellation, pure gamma/ramp safety, and panic-tap thresholds. This audit read their source; it did not execute them. `scripts/test-boost-hardware.sh` compiles a live gamma/readback harness, with optional Thread Sanitizer. The harness changes the physical display pipeline and must not compete with a running app. Existing SPEC also requires physical sleep/wake, lock, login, reconnection, and sustained-use checks beyond unit tests.

The current homepage is a static dark product page with blue links, gold download actions, two independent feature pillars, real multi-display photography, compatibility/color-response disclosures, keyboard focus styles, responsive grids, FAQs, structured data, and full 3.0.3 labels. The requested design documentation should record these existing choices without inventing new visual assets or claiming browser acceptance.

## Critical User Journeys

### Adjust the ring light

- **Given:** ring light is on and the HUD is visible.
- **When:** the user clicks an adjustment once, then holds it on a subsequent press.
- **Then:** click performs one existing coarse step; hold performs a coarse press step, then existing fine steps after 250 ms at 35 ms intervals. Release, pointer exit, disable, opacity auto-hide, order-out, view detachment, or close permanently cancels this press; reentry does not resume until a new press. Values remain clamped. Other controls do not repeat.

### Reveal only this screen's menu bar

- **Given:** Auto mode and two vertically stacked displays.
- **When:** the cursor enters the upper display while sharing the lower display's horizontal range.
- **Then:** the lower display's light does not retract. Entering its own menu-bar band retracts it; leaving restores it. Negative origins and horizontal boundaries remain valid.

### Operate independent tools with the ring off

- **Given:** ring light off and optional boost intent waiting for availability.
- **When:** the user inspects controls with assistive technology or opens the shortcut help.
- **Then:** ring-dependent controls remain disabled; bulb, boost cancellation, magnifier, desktop icons, reset, and hide remain available. Named actions and toggle values describe their behavior. Help includes ring, boost, brightness, and panic quit. No repeat mechanism can turn boost on.

## Technical Plan (Architecture)

Keep all component boundaries intact. Restore the small custom repeating button inside the existing control panel file and use the already present manager fine-step methods. Its tracking must keep the main run loop processing event-tracking/common modes so drawing and boost maintenance continue. Use one coarse action on initial mouse press, then fine callbacks; do not send the coarse action again on release. Cancel callbacks when the mouse press finishes or its control/window becomes unavailable. Native keyboard/accessibility activation remains a single action.

Add a pure menu-band membership helper beside the overlay implementation, taking point/frame/visible-frame inputs. The production sampler must call this same helper so geometry tests exercise the actual decision, not a parallel formula. Use half-open horizontal and upper vertical bounds to avoid two adjacent displays claiming one point. Require the point within that display and at/above its visible top edge.

Give all HUD buttons explicit stable accessible labels when constructed; toggles keep dynamic values, and menu-bar mode keeps its Below/Extend/Auto value. Retain tooltips, symbols, dimensions, grouping, and panel level. Keep the existing HUD material and overlap formula pending rendered contrast assessment. Correct any misleading baseline documentation to describe the material plus layer behavior. Choose no new palette or appearance system.

Update the existing help string and technical descriptions. No new dependency or persistence key is necessary. Keep the display boost implementation and recovery state untouched.


### Repeat lifecycle contract

`RepeatButton` keeps native `NSButton.mouseDown` tracking for highlighting and event delivery. Its cell explicitly opts into start/continue tracking; an exit cancels repeats while tracking continues to consume release. Send one coarse action before entering native tracking, suppress native release dispatch for that tracking session, and run a weakly captured fine-action `Timer` in `.common` mode after 250 ms, every 35 ms. Keyboard/accessibility `performClick` outside mouse tracking remains one coarse action. Only the six adjustment buttons get fine actions.

Use internal production entries `beginRepeating()`, `repeatTick()`, and idempotent `cancelRepeating()` so deterministic tests exercise real state and dispatch. Every tick checks the active press, enabled/highlighted state, attached visible window, and visible view before invoking its fine closure. An invalid condition cancels. Pointer exit permanently cancels; reentry waits for a new press. Native tracking returning also cancels, without a second coarse dispatch.

The panel's shared `cancelRepeatingAdjustments()` calls each repeating button's cancellation. Invoke it from alpha-only `autoHide()`, `orderOut(_:)`, and `close()`. A repeating button cancels from disable, view hiding/detachment, and its pointer-exit route. These paths must prevent a previously queued tick from mutating settings. Timer cancellation and all AppKit calls execute on the main thread. Preserve the existing background/material arithmetic; source-only opacity math does not establish contrast failure.

For tests, construct an **unstarted** manager and direct panel on `@MainActor`; never call manager start/stop or activate boost. Test coarse action wiring and each existing fine action direction/clamp, the timer's delay/interval, and cancellation by starting production repetition, invoking each actual cancel route, then invoking a queued production tick and observing unchanged settings. Use deferred cancellation/close. Existing snapshot restoration must include launch-at-login and original persistent-domain entries: restore singleton effective values first, then reset the saved domain (or remove it if originally absent), preserving missing keys as missing. No sleeps or physical gamma writes belong in these tests.

## Alternatives Considered

### Native periodic actions versus explicit fine-step timer

AppKit continuous buttons offer a periodic delay/interval, but a single target action does not by itself distinguish the required coarse press from fine repeats. Use native button tracking plus a small explicit common-mode fine-action timer so the panel can cancel alpha-only auto-hide, disable, and close through one tested path. Do not implement a second manual event-polling loop. [Apple periodic button API](https://developer.apple.com/documentation/appkit/nsbutton/setperiodicdelay(_:interval:)).

### Keep code unchanged and remove hold-to-repeat claims

This avoids interaction code but drops an existing documented fine-control journey while the fine-step actions remain in the manager. It also leaves stacked-screen behavior and help omissions unresolved. It is not selected for the authorized repair.

### Replace the HUD with sliders, labels, or a SwiftUI settings window

Sliders could make values easier to discover, but a new surface changes interaction, sizing, focus, and product identity. That is a separately scoped design decision and is not selected for this surgical pass.

### Rewrite global input, capture, display recovery, or settings management

Those systems have legitimate future validation needs. Changing them here would broaden risk far beyond the identified HUD/geometry/documentation gaps. Preserve existing boundaries and document unverified areas rather than treating a whole-product audit as authorization for speculative fixes.

## Non-Functional Requirements and Risks

- **Safety:** no gamma, boost timing, capability, render-lock, or session-eligibility changes. Existing regression suites must remain green. The repeating mouse path must continue common-mode maintenance.
- **Accessibility:** explicit semantic names and values are inspectable automatically; focus, announcement quality, contrast, and actual VoiceOver behavior require interactive verification. Do not label a source-only audit accessibility compliance.
- **Performance:** only one repeat session per held adjustment; no repeat timer after release/hide/close; unchanged ring/render cadence. Avoid new always-running timers.
- **Geometry:** test own-screen top band, point above/below, horizontal edges, stacked screens, negative coordinates, and zero-height menu band. Auto-hidden menu-bar behavior remains based on AppKit visible-frame reporting.
- **Privacy:** no new capture, network, analytics, credentials, or account handling. Keep proprietary artifacts in this repository.
- **Rollback:** revert the focused interaction commit(s) through a PR. No settings migration or display firmware change is introduced.
- **Delivery:** local YAML alone does not prove server enforcement. Inspect live repository rules and record any unavailable administrative capability. Required review/check gates cannot be bypassed for completion.

## Open Questions and Evidence Limits

- Actual VoiceOver/focus behavior, backdrop readability against bright/dark desktops, physical display behavior, recorder capture, and global input permissions are unverified until explicitly exercised and recorded.
- Magnifier capture-coordinate behavior on vertically stacked screens and no-display construction deserves a separate investigation; this design does not propose a speculative capture rewrite.
- Source alone cannot establish live GitHub rulesets, deployed Pages contents, signing credentials, or release acceptance. The coordinating agent reports live rules now require PRs with no bypass, strict Branch source policy and check-version checks, and zero human approvals for this solo repository; retain and verify that state before merging.
- No unresolved architecture choice blocks these bounded repairs. A broader request arising in review must be recorded as deferred or explicitly added to this draft before implementation.

## Detailed Implementation Plan

This boundary separates the design from implementation work. Five-stage fresh-context review is complete; its material findings are resolved in the lifecycle contract above and phased checkpoints below. Then implement the bounded plan and accepted feedback. Do not interpret optional audit observations as an unlimited refactor list.

### Phases and checkpoints

1. Install runtime/workflow documentation and verify live rules plus allowed/denied source cases. No Swift change in this phase.
2. Implement the production menu-band predicate and geometry cases. Run `make test` and `make build` before proceeding.
3. Implement repeat lifecycle, accessible names, help and isolated tests. Run `make test` and `make build`; cancel/clean up panels and restore persisted state.
4. Align SPEC and Impeccable context with shipped source, perform the Impeccable review and implement its bounded findings, then run final test/build/site/workflow/whitespace checks. Record every untested interactive/physical criterion separately. Recheck remote exact-head checks and automatic reviews before merge.

### Unified file and responsibility list

1. **Modify `MacEdgeLight/ControlPanelWindow.swift`.** Restore local `RepeatButton`; wire only six brightness/warmth/border buttons to their matching fine actions. Preserve press/release semantics, cancellation, enabled state, and common-mode processing. Add explicit labels to every action and stable mode identity. Preserve the current HUD material/opacity behavior unless visual review supplies concrete contrast evidence. Keep 44 pt targets, group ordering, native SF Symbols, auto-hide, and double-click bulb behavior.
2. **Modify `MacEdgeLight/EdgeLightOverlayWindow.swift`.** Add the small testable own-screen menu-band predicate and use it from `updateMenuBarReveal()`. Preserve 30 Hz polling and animated top-inset behavior.
3. **Modify `MacEdgeLight/StatusBarController.swift`.** Complete help content with Cmd+Shift+B, the five unmodified Q taps within two seconds, and independent ring/boost wording. Preserve menu action/state behavior.
4. **Modify `MacEdgeLightTests/AppSettingsTests.swift`.** Add focused behavior tests in the existing target/file for six step-button wiring and coarse/fine clamps, action accessible labels, three mode values, and screen-band boundary/stacked geometry using the production helper. Snapshot/restore modified preferences. Add repeat lifecycle regression coverage through the actual shared cancellation path where deterministic; avoid sleep-based timing tests. This avoids an otherwise unnecessary Xcode project change.
5. **Modify `docs/SPEC.md`.** Correct Button Types to match shipped repetition and cancellation. Separately correct toolbar grouping, NSEvent hotkey mechanism and complete shortcut list, same-screen menu-band bounds, material/backdrop description, and topology-preserving monitor behavior. Retain all boost/hardware acceptance requirements and distinguish source facts from measured acceptance. Update the dated specification header so it does not imply this is a 1.8-era app.
6. **Modify `README.md` only if reviewed implementation changes its current factual claims.** Preserve full 3.0.3 labels and all physical-brightness caveats. Existing hold claims become accurate when the missing interaction returns; do not add promotional scope or alter historical release notes.
7. **Modify repository `AGENTS.md`.** Put durable project guidance here alone: EGM artifact directory `docs/design`, project-local workflow entry points, source branch contract, and no bypass/manual-review requests. Replace stale companion-guidance wording; do not add rules to CLAUDE.md or private memories. Preserve safety guidance.
8. **Modify `.gitignore` and create project-local `.agents/` runtime support.** Track required EGM skills, personas, resources, integration docs, provenance/license, and Impeccable skill/runtime assets; ignore only generated/local state. The installed file list must be visible in staged changes and installation provenance, not hidden by a source ignore. No generated binaries or credentials belong here.
9. **Create/update `docs/design/design_draft.md` (this document), `docs/design/review_report.md`, `DESIGN.md`, and the Impeccable command's canonical design sidecar.** Record Goldfish findings and accepted/deferred decisions with source evidence; derive native HUD and separate website design sections from existing artifacts. Use the installed Impeccable document instructions to determine its exact sidecar path, and list that resolved path in the review/implementation record before writing it. Do not manufacture a visual approval or image-generation step for an incumbent product documentation task.
10. **Modify `.github/workflows/branch-policy.yml` only as needed to establish the required source check.** For target main accept same-repo develop only; for target develop accept same-repo nonempty `feature/*` only; reject fork sources. Keep `pull_request_target` handling metadata-only with read-only permissions and no PR checkout/execution. Preserve existing `check-version` in `.github/workflows/site-version.yml` without renaming or weakening it.
11. **Configure live repository rules through the authenticated GitHub interface, recording exact rule/check names in the implementation evidence.** Require PRs into main/develop, required branch-source and existing version checks, and no bypass. Copilot automatic review applies to develop PRs only. Never manually request reviews, create empty commits, or push no-op changes for reviews. Configuration is a server change, not evidence obtainable solely from local files. If admin capability is missing, report the exact remaining gate; do not silently weaken the contract.

### Verification and acceptance

- Run `make test` and `make build` after Swift changes, saving verbose output outside the repository and reporting actual results. The document itself does not assert either passed.
- Run `make check-site-version` and `git diff --check`. Parse/validate workflow syntax and exercise branch-source cases: allowed develop→main and feature/name→develop; disallowed arbitrary main source, plain feature/, fork source, and other develop source.
- In tests, verify all six single actions retain existing directions/clamps, hold wiring invokes the matching fine action, and cancellation leaves no further repeat callbacks. Exercise native mouse hold/release, pointer exit, hide/close, and menu tracking interactively; simulated callback tests do not replace this.
- Assert menu-band geometry deterministically for stacked/negative-origin layouts and boundary points using the production predicate. Manually inspect actual Auto reveal on a vertically stacked setup if available; otherwise label it untested hardware geometry.
- Inspect explicit names and current values through AppKit accessibility APIs; verify actual VoiceOver announcements and keyboard access interactively when available. Check the existing HUD against bright and dark desktop content and maximum border/bloom. Record observations rather than declaring visual acceptance from numeric alpha alone.
- Confirm bulb reset still preserves boost, magnifier, desktop icons, and capture visibility; default reset retains its existing broader semantics. Confirm ring-off independent-tool availability and waiting boost cancellation remain unchanged.
- Do not run the gamma harness automatically while another MacEdgeLight instance is active. If the reviewer expands changes into display-pipeline code, quit the app and run the existing normal/Thread Sanitizer hardware harnesses and physical checklist, labeling readback separately from luminance evidence.
- Recheck live PR base/head repository, exact commit, automatic review evidence, required checks, rules, and mergeability before any merge. Feature work goes to develop; develop goes to main only through its protected PR. No rebase, force push, or bypass.
- Stage all newly created project artifacts and inspect `git ls-files --others --exclude-standard`; leave no unexplained untracked project files. A staged draft is not a published release.

*Drafted with EGM*
