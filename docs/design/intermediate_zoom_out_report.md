# Stage 8 — Intermediate zoom-out

Reviewer `/root/goldfish_pipeline/zoom_intermediate`; fresh context (`fork_turns: none`). Full target 182 lines; initial/comprehension/critic reports supplied. No Blocker or Major findings. Prior findings had not yet been remediated.

- **Z8-1 — Nit:** `design_draft.md:97,113,139,174` leaves pointer exit/reentry and hide boundaries ambiguous. `ControlPanelWindow.swift:235–239,257–265` auto-hides by alpha. Resolve C6-1/D7-1 with explicit behavior and one shared cancellation path; avoid separate tracking state machines.
- **Z8-2 — Nit:** `design_draft.md:113,121–133,158` prescribes custom tracking without comparing native periodic tracking. Resolve D7-2 with a short requirements-based comparison.

C6-2 terminology links and T7-1 gamma wording remain useful editorial corrections. No architecture expansion required.

Read evidence: complete zoom-out persona/standard/target, all three context reports, README hold/product contracts, control construction/tracking/auto-hide and overlay geometry. Searched source/tests for repeat equivalents, periodic tracking, band logic and fine actions. Existing fine actions are suitable reuse; no repeat/menu-band helper found. No writes, builds, memory or subagents.
