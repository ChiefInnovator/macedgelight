Method: design review only (detector not applicable, native platform)

# MacEdgeLight native control panel review

Date: 2026-11-02. Mode: Operate. Primary target: `MacEdgeLight/ControlPanelWindow.swift`; related targets: `EdgeLightOverlayWindow.swift` and `StatusBarController.swift`. This is the pre-remediation review snapshot; resolution and subsequent test/build results belong in the implementation record.

## Provenance and scope

Fresh Assessment A by an isolated reviewer, after the EGM implementation. Read repository AGENTS.md, the local Impeccable macOS route first, compatible critique/craft-floor guidance, PRODUCT.md, DESIGN.md, `.impeccable/design.json`, the control-panel surface brief, resolved `docs/design/design_draft.md`, current native changes, relevant tests and SPEC. No detector findings or prior critique findings informed this assessment.

This is source inspection, not rendered acceptance. The coordinator reports 49 passing tests at the review checkpoint and a final build in progress; this reviewer did not rerun or independently certify those checks. The baseline desktop attempt exposed saved-hidden controls only as a capture-excluded overlay; the white screenshot establishes no HUD appearance, contrast or VoiceOver result. The reviewer did not launch or control the app. The native macOS route overrides web/mobile detection, overlay injection, browser and iOS guidance.

## Design specificity

The surface is convincingly specific to a screen-light utility: paired brightness/warmth/width adjustments, display selection, menu-bar coverage, capture visibility and independent tools belong together. SF Symbols, a nonactivating AppKit HUD, the 44-point targets and a restrained separator support brief adjustments over other work. Preserve that identity and incumbent material. A new palette, sliders, captions or alternate settings surface would exceed the repair contract.

The signature coarse-press/fine-hold interaction is now implemented, but its operation is absent from the adjustment controls' help. That is the largest remaining bounded opportunity. The source gives no basis for a contrast redesign.

Deterministic scan: not applicable (native AppKit platform).

## Design health

Scores are source-based judgments of the reviewed surface, not accessibility conformance or visual measurements.

| # | Heuristic | Score | Evidence / limit |
|---|---|---|---|
| 1 | Visibility of system status | 3/4 | ON/OFF, WAITING, enabled states and named menu-bar values; rendered announcement quality unverified. |
| 2 | Match with real world | 3/4 | Warmer/cooler, border and monitor actions use task language; symbol recognition still needs tooltip learning. |
| 3 | User control and freedom | 3/4 | Permanent repeat cancellation and independent boost cancellation are preserved; real tracking remains unverified. |
| 4 | Consistency and standards | 3/4 | Native button/cell tracking, menu alternatives, common-mode repeat timer and retained functional groups. |
| 5 | Error prevention | 3/4 | Clamps, disabled ring controls and cancellation guards; no extra release dispatch in the mouse path. |
| 6 | Recognition rather than recall | 2/4 | Icon-only row uses delayed help; fine-hold behavior is undisclosed (IMP-1). |
| 7 | Flexibility and efficiency | 3/4 | Coarse/fine adjustment plus global shortcuts and native menu; actual keyboard/AX activation needs acceptance. |
| 8 | Aesthetic and minimalist design | 3/4 | Source dimensions and two functional groups preserved; no rendered hierarchy/contrast claim. |
| 9 | Error recovery | 3/4 | Waiting boost remains cancellable, reset scopes remain distinct, exit/disable/hide cancel adjustment. |
| 10 | Help and documentation | 2/4 | Shortcut help includes boost and panic quit; per-adjustment precision help remains missing (IMP-1). |
| **Total** | | **28/40** | **Good; bounded clarity repair and manual acceptance remain.** |

## Priority finding

### IMP-1 — P2 — Precision adjustment is implemented but undisclosed

**Classification:** bounded interaction-discoverability gap; not a demonstrated event-tracking defect.

**Evidence:** `ControlPanelWindow.swift:217–222` defines only Brightness Up/Down, Warmer/Cooler and Thinner/Thicker tooltips; `:267–270` copies these into image descriptions, tooltips and accessible labels. The actual special behavior exists at `:68–89`: an immediate coarse step followed by delayed fine steps. No accessibility help or tooltip describes holding for fine adjustment. Native keyboard/accessibility activation intentionally performs one coarse step (`AppSettingsTests.swift:194–198`).

**User impact:** a first-time user can find the action but cannot discover the promised precision interaction through its help. A VoiceOver user also receives no explicit explanation of the pointer-only hold behavior and single-action keyboard/accessibility alternative. This does not establish that VoiceOver is broken.

**Exact bounded fix:** retain stable action labels and all geometry/symbols. On the six repeat buttons, add concise tooltip and `setAccessibilityHelp` text explaining “Click for one step. Hold for fine adjustments. Release or move outside to stop.” Preserve shortcut text and keep keyboard/accessibility activation as one step. Add focused assertions for nonempty precision help on exactly those six controls and unchanged stable labels. Do not make toggles repeat or add timer behavior.

**Suggested command:** Impeccable clarify, within the native source route.

### IMP-2 — P2 — Custom drag cancellation relies on inherited tracking opt-in

**Classification:** bounded tracking-contract correctness gap; no reproduced native pointer failure is claimed.

**Evidence:** `ControlPanelWindow.swift:4–15` overrides continuation and stop callbacks but not `startTracking(at:in:)`; continuation delegates its return value to the superclass. The cell is not configured for continuous/drag action delivery. Apple documents that [startTracking](https://developer.apple.com/documentation/appkit/nscell/starttracking(at:in:)) defaults to accepting tracking for continuous/drag-responsive cells, and [trackMouse](https://developer.apple.com/documentation/appkit/nscell/trackmouse(with:in:of:untilmouseup:)) invokes continuation only when tracking starts successfully. [continueTracking](https://developer.apple.com/documentation/appkit/nscell/continuetracking(last:current:in:)) also has a conditional default. An inherited NSButtonCell behavior is not an explicit guarantee for this custom cancellation contract.

**User impact:** permanent cancellation on a short exit/reentry must observe the drag event, rather than depend solely on a 35 ms timer seeing an unhighlighted button. Tests currently invoke continuation directly (`AppSettingsTests.swift:239–241`); they do not check that the actual cell opts into these callbacks.

**Exact bounded fix:** override `startTracking(at:in:)` to explicitly accept the enabled RepeatButton's tracking. Make the custom continuation return its own deliberate boolean instead of inheriting the noncontinuous cell's default; on exit cancel permanently, and retain whichever native tracking duration is necessary to finish the release cleanly. Preserve the single coarse press, suppressed release dispatch and separate common-mode fine timer. Add assertions through the actual button cell for start and multiple in-bounds continuation calls, then exit/reentry and a pending tick with no further setting change. Actual pointer delivery remains manual acceptance.

**Suggested command:** Impeccable harden, within the native source route.

No P0/P1 issue or additional concrete implementation defect was found in this scope. Do not manufacture further findings to meet a generic critique template.

## Strengths

- `ControlPanelWindow.swift:4–15,51–95`: native cell exit/release hooks, suppressed coarse release dispatch, weak timer capture and an idempotent cancellation state form a coherent lifecycle once explicit tracking opt-in is addressed (IMP-2). The production tick rechecks availability before mutation. This is source reasoning, not proof that real AppKit tracking delivers every expected event.
- `ControlPanelWindow.swift:339–360,436–474`: panel hide/order-out/close share cancellation while ring-dependent controls and always-active tools remain separate. A waiting boost preference stays cancellable independently of ring state.
- `EdgeLightOverlayWindow.swift:3–9,125–130`: the same pure predicate used in production constrains Auto reveal to its own screen with half-open boundaries. The deterministic cases cover stacked and negative-coordinate displays. Shortcut help now names ring brightness, boost and the unmodified five-Q panic exit (`StatusBarController.swift:147–158`).

## Cognitive load and emotional journey

The task is short and direct: change one ring parameter or operate an independent tool. The row contains 17 actions, divided into 11 ring-dependent and six always-active actions (`ControlPanelWindow.swift:216–249`). Both groups exceed the generic four-choice checklist. Paired controls, disabled states and the separator provide meaningful chunking, but no internal labels reduce first-use symbol learning.

Checklist: single focus passes for a known adjustment; chunking fails the generic size threshold; related grouping passes; visual hierarchy is unverified from source; one decision at a time passes; minimal choices fails; working memory is acceptable once the symbol is learned, with IMP-1 requiring recall of undocumented behavior; progressive disclosure is partial through tooltips and the menu. This is moderate source-observable learning load, not evidence that users are confused or abandon the task. Rebuilding the row is outside the preservation brief.

The intended emotional arc is immediate feedback, finer control during a hold, then a reliable stop. Cancellation and clamps provide reassurance. Missing precision help creates the main learning valley; lack of rendered acceptance prevents judging whether hover, highlight or fade communicates that arc successfully.

## Persona checks

- **Jordan, first-time user:** can discover Warmer through a tooltip, but cannot infer fine-hold adjustment from it (IMP-1). Seventeen icons require initial scanning; retain the native menu alternative rather than expanding this repair into a redesign.
- **Alex, power user:** global ring/brightness/boost shortcuts and one-action native activation support efficient use. No source defect identified; real hold/release, event-tracking continuity and accidental second dispatch still require manual exercise.
- **Sam, assistive-technology user:** all 17 buttons now have explicit nonempty names and menu mode exposes Below/Extend/Auto. Precision help is missing (IMP-1). Actual VoiceOver order, announcements, focus access and auto-hide behavior remain untested; do not infer acceptance from getter tests.

## Manual acceptance still open

These are evidence gaps, not code-defect findings and not authorization for speculative changes:

1. Exercise the six real mouse holds: one coarse press, fine steps after the delay, no second coarse release; exit/reentry does not resume. Repeat while menu/event tracking is active, then disable, auto-hide, order out and close. The tests invoke production hooks and cell methods directly; they do not drive a complete native tracking session.
2. With VoiceOver and keyboard navigation, verify labels, toggle values, three menu modes, waiting boost cancellation, one-action activation, focus order and usable access to fading controls.
3. Inspect the actual HUD against bright/dark desktops and maximum ring/bloom, including disabled icons and hover states. The material plus background layer is composited by AppKit; source alpha cannot establish contrast ratios.
4. Verify own-screen Auto reveal on a physical stacked-display setup and retain all SPEC display/gamma/lifecycle acceptance. No display-pipeline code changed in this repair.

Minor observation: stable bulb action naming and the tooltip retain distinct reset semantics; double-click remains a pointer gesture. Its actual assistive-technology discoverability is part of the open manual checks, not a newly demonstrated defect.

Questions skipped: the user authorized the bounded review and implementation of its feedback. No unresolved design choice blocks IMP-1 or IMP-2; broader layout, display-pipeline and visual changes remain outside scope.
