# Stage 9 — Implementation readiness

Target `design_draft.md:152–182`; feature section read as context. All reviewers fresh (`fork_turns: none`), read-only. Findings apply to pre-remediation draft/source. No Blockers.

## Implementation — /root/goldfish_pipeline/readiness_impl

- **I9-1 — Major:** `design_draft.md:158,174` leaves repeat lifecycle underspecified. Pointer exit, release outside, orderOut and opacity-only auto-hide need exact cancellation hooks. Specify permanent cancellation on exit until new press, one idempotent method, main-thread common-mode tracking, deterministic test entry points/assertions. Baseline `ControlPanelWindow.swift:235–240,257–266`; `EdgeLightManager.swift:442–446`.
- **I9-2 — Major:** `design_draft.md:161` lacks UI-test construction/cleanup. Manager start creates overlays/restores gamma/reconciles boost/registers hotkeys (`EdgeLightManager.swift:35–74`). Require @MainActor tests with an unstarted manager and direct panel construction; production repeat-session hooks without sleeps; deferred cancellation/panel cleanup and preference restoration. Prohibit manager start/stop and physical boost activation.
- **I9-3 — Major:** `design_draft.md:156–179` lacks incremental buildable/testable phases. Divide into runtime/workflow documentation, geometry plus deterministic tests, repeat/accessibility plus tests, final documentation/acceptance; specify checks after each Swift phase.

Read complete implementation_readiness persona/readiness standard/target, complete control panel and overlay, AppSettingsTests, manager construction/control/lifecycle and both workflows.

## Codebase — /root/goldfish_pipeline/readiness_code

- **B9-C1 — Major:** `design_draft.md:158,161,174` leaves production cancellation API/event routing/test seam undecided. Add one idempotent `cancelRepeating()`; route release/disable/orderOut/close/alpha-auto-hide through it. Add manually invocable production repeat tick. Tests start actual button repetition, invoke each production cancellation route, then invoke pending tick and assert no setting change. Specify pointer exit behavior. Baseline auto-hide `ControlPanelWindow.swift:235–239`, disable `352–355`, hide `EdgeLightManager.swift:442–446`.
- **B9-C2 — Nit:** `design_draft.md:161` snapshot helper restores effective settings through setters, creating keys previously absent (`AppSettingsTests.swift:175–208`, setters `AppSettings.swift:25–38`). Snapshot original persistent-domain entries/presence; restore singleton values first, then restore/remove original persisted entries.

No geometry or branch-policy finding. Half-open own-frame band is sufficiently specified, including empty band. Metadata-only read-only pull_request_target source policy rejects forks/empty feature names and never executes PR source; check-version remains separate.

Read complete codebase_details persona/readiness standard/draft; inspected relevant control/action/lifecycle, overlay sampler, settings setters/test helper, manager fine/hide actions, app startup, hosted-test configuration and workflows.

## Style — /root/goldfish_pipeline/readiness_style

- **T9-1 — Nit:** `design_draft.md:158`: use “Add explicit labels to every action and stable mode identity. Preserve the current HUD material/opacity behavior unless visual review supplies concrete contrast evidence.”
- **T9-2 — Nit:** `design_draft.md:162`: use “Correct the Button Types description to match shipped repetition. Update toolbar grouping, the NSEvent hotkey mechanism, the complete shortcut list, same-screen menu-band bounds, material/backdrop description, and topology-preserving monitor behavior.”

Read complete style persona and target 152–182; checked terms elsewhere; no extra standard.
