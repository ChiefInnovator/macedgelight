# Consolidated fresh Goldfish review

Date: 2026-11-02. Reviewed baseline: `docs/design/design_draft.md`, 182 lines. Semantic boundary: feature 1–151, detailed implementation 152–182. Five stages completed sequentially; independent personas within stages 7/9 dispatched directly. Every reviewer used native `spawn_agent` with `fork_turns: none`, read its required persona/standards and returned a completed result before synthesis. No reviewer used memory/history, modified production code, or ran physical tests.

## Priority actions

### A1 — Major: Define and test one repeat lifecycle

Resolve pointer exit as permanent cancellation until a new press. Specify one idempotent production cancellation method and exact release, disable, opacity-auto-hide, orderOut and close hooks. Keep main-thread common/event tracking alive. Provide a deterministic production repeat tick; tests start actual repetition, cancel through each real route, invoke a pending tick and assert no setting change. Review cannot infer correctness from a timer-only model or sleep-based checks.

Sources: draft97,113,139,158,161,174; baseline panel235–240,257–266,352–355 and manager442–446. Raw IDs: C6-1, D7-1, Z8-1, I9-1, B9-C1.

### A2 — Major: Isolate UI tests from physical display behavior and persistence

Use @MainActor tests, unstarted manager and directly constructed panel. Never start/stop the manager or enable physical boost for these tests. Defer panel cancellation/cleanup and singleton restoration. Preserve original persistent key presence as well as effective values: snapshot domain entries; restore singleton values first, then restore/remove saved entries.

Sources: draft161; manager35–74; settings setters25–38; test helper175–208. Raw IDs: I9-2, B9-C2.

### A3 — Major: Add implementation phases and checkpoints

Order work as runtime/workflow docs, geometry plus tests, repeat/accessibility plus tests, final documentation/acceptance. Name build/test checkpoints after Swift phases; retain final site/workflow/diff checks and untested physical acceptance limits.

Source: draft156–179. Raw ID: I9-3.

### A4 — Nit: Explain the native tracking alternative

Briefly compare AppKit periodic tracking with the required coarse-on-press/fine-repeat/cancellation contract. Retain custom tracking only with that rationale. Source draft113,121–133,158. Raw IDs: D7-2, Z8-2.

### A5 — Nit: Clarify workflow names and wording

Define/link EGM/Goldfish and Impeccable at first introduction. Explain gamma as capped at 1.55 and 90% of current headroom with neutral floor1.0. Separate accessible-label and appearance instructions; separate Button Types correction from other SPEC topics. Sources draft12,32,77,158,162,165–166. Raw IDs: C6-2, T7-1, T9-1, T9-2.

## Traceability

| Raw finding | Severity | Consolidated action |
| --- | --- | --- |
| C6-1 | Nit | A1 |
| C6-2 | Nit | A5 |
| D7-1 | Nit | A1 |
| D7-2 | Nit | A4 |
| T7-1 | Nit | A5 |
| Z8-1 | Nit | A1 |
| Z8-2 | Nit | A4 |
| I9-1 | Major | A1 |
| I9-2 | Major | A2 |
| I9-3 | Major | A3 |
| B9-C1 | Major | A1 |
| B9-C2 | Nit | A2 |
| T9-1 | Nit | A5 |
| T9-2 | Nit | A5 |

Initial zoom-out and structural reviewer returned no findings. Four raw Majors consolidate to three Major actions; no Blockers. Repeated later findings retain their originating IDs rather than being counted as new defects.

## Completion evidence

| Stage | Completed fresh reviewer | Persona / standard | Report |
| --- | --- | --- | --- |
| 5 | /root/goldfish_pipeline/zoom_initial | zoom_out / zoom-out-standard | zoom_out_report.md |
| 6 | /root/goldfish_pipeline/comprehension | comprehension / none | comprehension_report.md |
| 7 | /root/goldfish_pipeline/critic_design | design_critic / feature-spec-standard | critic_report.md |
| 7 | /root/goldfish_pipeline/critic_structural | structural / feature-spec-standard | critic_report.md |
| 7 | /root/goldfish_pipeline/critic_style | style / none | critic_report.md |
| 8 | /root/goldfish_pipeline/zoom_intermediate | zoom_out / zoom-out-standard | intermediate_zoom_out_report.md |
| 9 | /root/goldfish_pipeline/readiness_impl | implementation_readiness / implementation-readiness-standard | implementation_readiness_report.md |
| 9 | /root/goldfish_pipeline/readiness_code | codebase_details / implementation-readiness-standard | implementation_readiness_report.md |
| 9 | /root/goldfish_pipeline/readiness_style | style / none | implementation_readiness_report.md |

Persona paths resolve beneath `.agents/agents/`; standard paths beneath `.agents/resources/document_standards/`. Each stage report records required-read confirmation and actual source inspection. Target remained unchanged throughout the pipeline. Coordinator persisted reports; reviewers remained read-only.

## Evidence limits and repair scope

The screen-band contract and trusted branch workflow are sufficient for bounded implementation. Local workflow review establishes metadata-only execution, same-repository/nonempty feature source validation and separate version check; live rules/check runs remain separate evidence. Automated settings/geometry/cancellation checks cannot establish real mouse tracking, VoiceOver, backdrop contrast, physical brightness, sleep/logout or recorder behavior. Preserve display-pipeline code and all pending physical acceptance requirements. Apply accepted repairs in the existing files; do not expand this report into speculative product redesign.
