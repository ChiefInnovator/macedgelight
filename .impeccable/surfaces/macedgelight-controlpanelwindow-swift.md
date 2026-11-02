---
version: 1
slug: "macedgelight-controlpanelwindow-swift"
primary_target: "MacEdgeLight/ControlPanelWindow.swift"
related_targets: ["MacEdgeLight/StatusBarController.swift","MacEdgeLight/EdgeLightOverlayWindow.swift"]
---

# Native control panel surface brief

## Scope and mode

Mode: Operate. Primary target: `MacEdgeLight/ControlPanelWindow.swift`. Related targets are the native status menu and own-screen overlay menu-band logic. Preserve the incumbent; this is a focused interaction repair, not a new visual world. Durable product truth: `PRODUCT.md`. Visual authority: `DESIGN.md`, extracted from actual Swift. Reviewed repair scope: `docs/design/design_draft.md` and `docs/design/consolidated_review_report.md`.

## User, task and evidence

A Mac user adjusts ring light while working or presenting and operates independent boost/magnifier/desktop tools even with the ring off. The native menu and global shortcuts provide parallel paths. Keep actionable accessible names and current toggle/waiting values. Do not treat physical brightness, VoiceOver, backdrop contrast or actual pointer tracking as accepted from source/unit tests.

## Direction contract

**THESIS:** Restore the existing compact native HUD's promised precision and truthful state. Preserve the horizontal task arrangement; this scope introduces no alternative settings surface.

**OWN-WORLD:** Retain dark AppKit HUD material, white SF Symbols, source dimensions, separator and drag grip. Keep the light-dependent and always-active groups and native window levels.

**STORY:** A user can distinguish ring lighting from boost, make one coarse adjustment or hold for fine steps, and cancel waiting boost. Help reflects all existing shortcuts.

**FIRST VIEWPORT:** Existing nonactivating floating control row over the user's desktop. Preserve its geometry, labels and symbols; explicit accessibility labels do not require adding visible captions.

**SIGNATURE INTERACTION:** Coarse-on-press then fine hold adjustment. Exit cancels until a new press. Release, disable, opacity-auto-hide, orderOut and close share idempotent cancellation. Keyboard and accessibility activation perform one action.

**PROOF AND LIMITS:** The geometry checkpoint passed 46 tests and a Debug build; the complete interaction checkpoint passed 49 tests and a Debug build. Production lifecycle/geometry checks are automated evidence. Actual mouseDown tracking, VoiceOver, focus and bright/dark desktop contrast remain pending, alongside hardware acceptance. Local `reference/macos.md` supplies source-only desktop routing; the upstream platform enum/engine and native live preview remain unsupported. Sidecar HTML is illustrative only.

Seed/reference: incumbent Swift implementation; no comp generation or random visual seed applies to this preservation task.

## Implemented repair sequence

1. Source-derived context and runtime/workflow documentation recorded.
2. Own-screen Auto menu-band membership repaired and geometry checkpoint passed.
3. Hold lifecycle, accessible names and shortcut help implemented; production hooks tested with an unstarted manager and no physical boost. Tests preserve exact persistent-key presence during cleanup.
4. SPEC reconciled and Swift build/test checkpoint passed. Final site/workflow/diff checks and live acceptance evidence are reported separately by the coordinator.

The implementation retains native AppKit cell tracking, with a separate fine-step timer to meet the coarse-on-press, delayed fine repeat and permanent cancellation contract. Native periodic action alone would not express that split. Keyboard/accessibility paths remain single-action.

## Constraints and unresolved acceptance

No gamma, rendering/recovery, capture, palette, opacity, layout, version or marketing redesign is included. Focused repairs are implemented and source/automated checkpoints passed; no finish-review verdict is implied. A baseline app launch left saved controls hidden; capture-excluded overlay inspection and a white screenshot did not establish HUD appearance. Real interaction, VoiceOver, focus, contrast and hardware acceptance remain unresolved. No architecture choice blocks the bounded repairs.
