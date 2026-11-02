# Stage 7 — Feature critics

Target `design_draft.md:1–151`; implementation 152–182 read as context. All reviewers used fresh context (`fork_turns: none`) and read-only roles. No Blocker or Major findings.

## Design critic — /root/goldfish_pipeline/critic_design

- **D7-1 — Nit:** `design_draft.md:97,113,139` leaves drag-out behavior undefined. `ControlPanelWindow.swift:257–265` starts auto-hide after pointer exit; auto-hide lowers alpha (`235–239`). Specify exit/reentry behavior and explicitly cancel alpha-based auto-hide; test the chosen behavior deterministically.
- **D7-2 — Nit:** `design_draft.md:121–133` omits native periodic tracking versus a custom mouse loop. Briefly explain whether native tracking satisfies coarse-on-press/fine-repeat and lifecycle cancellation, and why custom tracking is retained.

Read complete design_critic persona, feature-spec standard, target; checked control-panel tracking/auto-hide/action construction, overlay tracking, manager actions and README/SPEC repeat claims. No writes, builds, or hardware checks.

## Structural — /root/goldfish_pipeline/critic_structural

No S7 findings. Hierarchy, fences, lists, problem, boundaries, alternatives and risks are coherent. Read complete structural persona and feature-spec standard; target 1–151, remainder context.

## Style — /root/goldfish_pipeline/critic_style

- **T7-1 — Nit:** `design_draft.md:77` leaves the relationship between gamma limits unclear. Use: “Gamma uses fresh synthetic linear ramps, capped at 1.55 and 90% of each display’s current headroom, with a neutral floor of 1.0.”

Read complete style persona and target; no extra standard supplied.
