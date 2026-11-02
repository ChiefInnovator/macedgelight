# Implementation and verification evidence

Date: 2026-11-02. Product marketing version remains 3.0.3; no release was published.

## Review sequence

1. Project-local EGM full runtime installed from Google revision `403d8881d62022490637d740657b33f01e321ea8`; 76 files byte-matched that revision before explicitly recorded local integration patches.
2. Project-local Impeccable skill 4.8.0 / engine 0.1.18 installed; generated engine binary ignored. `engine-probe` returned `impeccable-engine 0.1.18`.
3. Whole-product design drafted, then five Goldfish stages completed with nine fresh reviewers. Original reports preserve their 182-line target. All five consolidated actions A1–A5 accepted and incorporated into the canonical draft; see `goldfish_resolution.md`.
4. PRODUCT.md, DESIGN.md, extension sidecar and native Operate surface brief created from incumbent source before production edits.
5. Goldfish repairs implemented with phase checkpoints below. A completed fresh native Impeccable source review identified IMP-1/IMP-2 in `impeccable_review.md`; both are accepted and implemented as documented below.

## Goldfish implementation traceability

| Action | Implementation | Automated evidence |
| --- | --- | --- |
| A1 | RepeatButton native tracking, delayed common-mode fine timer, explicit shared cancellation paths, guarded pending ticks | Six coarse/fine/clamp paths; actual release/exit/disable/hide/detach/orderOut/close/alpha-hide hooks and queued Timer.fire() checks |
| A2 | Unstarted manager and direct main-thread test panel; deferred cancellation/close; singleton restoration then original persistent-domain restoration including key absence and launch-at-login | Tests never start manager or activate physical boost; preference snapshot code covers original domain presence |
| A3 | Geometry checkpoint followed by interaction checkpoint and final documentation/runtime/CI validation | Geometry 46 tests and build pass; interaction 49 tests and build pass |
| A4 | Native tracking retained; explicit fine timer permits cancellation and different coarse/fine dispatch without custom mouse event loop | Production cell tracking hooks used by tests; physical mouse tracking remains manual |
| A5 | Workflow definitions/links, gamma wording and split instructions in design; complete help and corrected SPEC | Source review, full tests/build, site version check |

The screen-band helper is called by the production sampler and checked for own-screen membership, stacked and negative-origin displays, half-open edges and empty bands. No gamma/rendering/recovery source was changed.

## Local checks

- Baseline: `make test` passed 45 tests; `make build` succeeded.
- Geometry phase: `make test` passed 46 tests; `make build` succeeded. Logs `/tmp/macedgelight-geometry-test.log`, `/tmp/macedgelight-geometry-build.log`.
- Interaction phase: `make test` passed 49 tests; `make build` succeeded. Logs `/tmp/macedgelight-interaction-test.log`, `/tmp/macedgelight-interaction-build.log`.
- `make check-site-version`: marketing version 3.0.3 verified.
- `actionlint .github/workflows/branch-policy.yml`: passed. Exact source predicate passed 12 local allow/deny cases.
- `python3 .agents/scripts/check-installation.py`: passed runtime JSON, reviewer/standard resolution, worker schema shape, skills/icons, scenario fixtures and desktop routing checks.
- Ephemeral JSON Schema validation accepted a complete worker response and rejected omission of each required contract array; all seven behavioral YAML suites parsed. No project dependency files added. Model-driven skill scenario suites were not run.
- Authored staged/unstaged diffs passed whitespace checks. Upstream vendored files retain their original formatting except listed local integration patches.

## Automatic Copilot integration review

Initial PR #3 review completed automatically at head `8b437fa6b31749f2f5db45ca2596dd7315060b80` and identified 17 integration comments. The addressed categories were reviewer filename keys, icon paths, upstream packaging/test scope, worker required arrays, fresh-context stop behavior, scenario fixtures/intake, and honest macOS routing. `.agents/INSTALLATION.md` and source provenance list exact local patches. No manual review request, empty commit, or no-op push was made. Final exact-head review/CI must be checked after the real implementation push.

## Server enforcement

See `../BRANCH_WORKFLOW.md` for rule IDs and live positive/negative run evidence. Main and develop have active PR/check rules with no bypass actors, merge commits only, strict source/version checks, deletion/force-push protection, and resolved review threads. Copilot automatic review is scoped to develop only. Required human approvals are zero for this solo-maintainer repository.

## Native and physical limits

The baseline debug app was inspected through CUA, but saved controls were hidden and its capture-excluded overlay yielded a white screenshot. It was closed through the existing five-Q panic gesture. That attempt provides no HUD contrast or rendered acceptance. Deterministic tests construct a direct panel, not a started manager, and invoke production hooks; they do not replace physical pointer tracking or assistive-technology testing.

Actual mouse hold/release/reentry, keyboard focus, VoiceOver announcements, desktop contrast, multi-display hardware, recorder behavior, sustained physical brightness, sleep/wake/logout and hardware gamma-harness acceptance remain manual. The existing SPEC checklist remains required before claiming those outcomes. No hardware harness or display-pipeline change was made for this task.

## Impeccable resolutions

- **IMP-1 (P2):** six adjustment buttons now explain click/hold/exit in tooltips and explicit accessibility help, while preserving short stable accessible labels and all dimensions. Tests assert hints on those six controls and their absence on unrelated buttons. SPEC matches.
- **IMP-2 (P2):** the actual installed native cell returned false from inherited startTracking and in-bounds continueTracking. A targeted pre-fix test produced five expected assertion failures (`/tmp/macedgelight-impeccable-imp2-before.log`), demonstrating the missing opt-in/continuation contract, not a reproduced physical gesture. Explicit cell start/continue tracking keeps AppKit consuming release while exit permanently cancels repeats. Tests cover actual cell start, multiple in-bounds drags, exit, reentry and pending callbacks. Final test/build outcomes are recorded after the repair below.

The original review is preserved as a pre-remediation snapshot. No palette/layout/gamma changes follow from these findings, and unresolved physical/assistive-technology checks remain open.

Final Impeccable repair checkpoint: `make test` passed **49 tests, zero failures** and `make build` succeeded. Logs: `/tmp/macedgelight-impeccable-imp2-test.log` and `/tmp/macedgelight-impeccable-imp2-build.log`. The earlier IMP-1 checkpoint also passed 49 tests/build. Runtime installation, workflow syntax, site version and authored whitespace checks pass.
