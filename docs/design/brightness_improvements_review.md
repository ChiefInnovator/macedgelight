# Goldfish review: brightness improvements draft

- **Target:** `docs/design/brightness_improvements_draft.md`
- **Date:** 2026-11-04
- **Reviewers (fresh context, read-only):** zoom-out, comprehension, design critic, implementation readiness, codebase details
- **Deviation from `egm-review`:** the five reviewers ran in parallel, not in the sequential stage order 5→9, and no remediation ran between stages. Stage 6 (comprehension) and stage 9 (readiness) therefore reviewed the same unrevised draft. Existing `docs/design/*_report.md` files belong to an earlier review and were not overwritten.
- **Not verified:** the BrightIntosh claims (commit `f6806b8`) come from one subagent's read of a shallow clone; no reviewer re-checked them. Apple API behavior (thermal notification thread) was not confirmed offline.

## Verdict

Not ready to implement. One blocker invalidates the core of item 2 (conflict detection). Phase 1 (adjustable strength) is sound in direction but has gaps. Recommended: narrow the draft to Phase 1 plus a corrected, evidence-gated Phase 2, and move thermal and diagnostics out.

## Blockers

| # | Finding | Raised by |
|---|---|---|
| B1 | The readback runs right after our own write, so it almost never sees another writer (a competing tool writes in the 0.5 s gap). It would only flag our own quantization. Fix: read at the start of the tick, before rewriting, and compare to the last ramp we wrote. Then grace handling must cover our own `resetGammaToProfile()` in `rebuildOverlays` and wake. | comprehension, critic, codebase |
| B2 | D1, D2, D3 are undecided but the UI, hotkey, tick-arithmetic and thermal rows depend on them. | readiness, zoom-out |
| B3 | Conflict thresholds contradict themselves (3 ticks at 0.5 s is about 1.5 s, not 3 s; "10 clean ticks" is 5 s or 20 s depending on D2). Grace period and tolerance have no values; a 0.002 tolerance already exists in `scripts/BoostHardwareCheck.swift` (`checkRamp`). | all five |

## Major

1. **Scope.** Only strength has a demonstrated user need. Conflict detection, thermal status and the diagnostics buffer rest on "BrightIntosh has it." (zoom-out)
2. **Alternating writers never reach `persistent`.** Consecutive-mismatch rules reset on every clean tick; use N mismatches in M seconds. (critic)
3. **Slider dead zone.** `desired = 1 + level×0.55` is clamped by `0.9×headroom`; at about 1.3× headroom every level above about 0.31 gives the same output. Scale against the effective ceiling or document it. (critic)
4. **Level 0 is "ON" with no gain.** The overlay, display link and timer keep running, and the overlay requests headroom regardless of gamma scale (`renderFrame`, `appliedHeadroom`). The "less heat and battery" claim in Problem 1 is not supported by the design. Drop the claim or define level 0. (critic, codebase, comprehension)
5. **Continuing to write during a conflict keeps the flicker** and gives the user no remedy besides turning boost off. Add a mitigation (pause action, write backoff) or justify. (critic, comprehension)
6. **Thermal message asserts a cause** the app cannot verify; reword to "thermal state: serious." Thermal notifications should register on the main queue. (critic, codebase)
7. **Reuse misses.** `EDRInfoWindow.gammaDeviation` and `BoostHardwareCheck.gamma(for:)` already read gamma back using the API's own sample count (do not hard-code 256). `EDRInfoWindow.refresh()` builds its report inline and calls the private `DisplayServicesGetBrightness` via `dlopen`; a shared release-path builder must exclude that call. Extending the existing report may meet Problem 4 without a ring-buffer subsystem. (zoom-out, codebase)
8. **Wrong reset target.** Ring-light reset is `EdgeLightManager.resetRingLight()`, which does not touch `AppSettings`. The real question is whether `AppSettings.resetToDefaults()` and `EdgeLightManager.resetToDefaults()` reset `boostLevel`. `AppSettingsTests` needs `boostLevel` in `SettingsSnapshot` or tests leak into `UserDefaults`. (codebase)
9. **Harness breaks.** `scripts/test-boost-hardware.sh` compiles only `DisplayBrightnessManager.swift` and `BoostHardwareCheck.swift`; new dependencies must be added to the `swiftc` line, and the manager must receive `boostLevel` by injection, not import `AppSettings`. An in-process external ramp does not reproduce a cross-process writer. (codebase)
10. **Unspecified APIs and behavior.** No signatures for `desiredGammaScale`, `boostStatus`, `BoostDiagnostics`, the per-display snapshot, or a public entry for the private `refreshGamma`. No precedence when waiting, conflict and thermal overlap. Existing consumers treat a non-nil `boostRecoveryMessage` as "WAITING" and need changes. Pure-function extraction is needed to test the status merge. (readiness, comprehension, codebase)
11. **Phasing is not buildable per phase.** Phase 2 needs `BoostDiagnostics` from Phase 3; the file table has no phase column; `KnownConflictApps` has no phase. (readiness, comprehension, codebase)
12. **Current behavior is not self-contained.** Glossary needed for ramp, headroom, tick, settle time, ColorSync restore. (comprehension)
13. **Known-conflict app list adds a file and goes stale** while being "hint only." Cut it. (zoom-out)
14. **Altitude.** File and test tables and field names are implementation detail inside the design doc. (zoom-out)

## Nits (grouped)

- Open-decision defaults the zoom-out reviewer suggested: D1 menu-only, D2 every tick, D3 notify-only. These are the owner's call; the reviewer's reasoning is recorded here, not adopted.
- Resolved facts: `CLAUDE.md` mirrors the architecture list, so it must be edited. `stop()` should follow the existing order (recovery first, observers last), not "observers first." `add_test_target.rb` exits if the target exists, so the new files need manual `pbxproj` entries. SPEC rows should also cover Settings, EDR Diagnostics Window, Global Hotkeys and the architecture tree.
- Stale line numbers in prose; process items (release notes, version bump) are out of scope; mark each file row Create/Modify/Delete; state memory-only ring buffer limit and clipboard exposure; BrightIntosh constants in the Overview weaken the clean-room claim (note ours are independently derived); the Problem 2 flicker is hypothesized, not reproduced; no go/no-go criterion for item 2 in Goals; failed writes should skip readback and not count as mismatches; D1-A's "hard with hold-to-repeat" is unverified; lid-closed in Deferred but not in Non-Goals.

## Confirmed accurate

`gammaScale` 1.55 (`DisplayBrightnessManager.swift:57`), `maintainBoost` (line 177), 0.90 safety, 0.5 s timer, 0.75 s/2 s settle times, 30 s manual interval, 24 recovery orderings, `EDRInfoWindow` debugger-only, `NSLog`-only write failure.

## Decisions needed from the owner before a revision

1. Scope: Phase 1 only, or Phase 1 plus corrected conflict detection?
2. D1 strength control form (slider / stepped / menu-only).
3. D2 readback frequency; D3 thermal response (only if those items stay in scope).
4. Conflict mitigation: pause action, write backoff, or accept continued writes.

## Traceability

B1 ← comprehension #1, critic B1, codebase B1. B2 ← readiness #1, zoom-out #7. B3 ← comprehension #2–3, critic M1, readiness #2–3, codebase M1. Majors 1, 13, 14 ← zoom-out #1, #3, #6. Majors 2–6 ← critic M2–M6. Majors 7–9 ← codebase M2, M3, M5, M7, zoom-out #4–5. Majors 10–12 ← readiness #4–8, comprehension #4–7, codebase M4, M8.
