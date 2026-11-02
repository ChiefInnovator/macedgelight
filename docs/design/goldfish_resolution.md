# Goldfish finding resolutions

The five-stage review in `consolidated_review_report.md` evaluated the original 182-line draft.
All five consolidated actions are accepted. The reviewed draft remains the canonical design,
updated with the resolutions below; original reports retain their baseline line references.

- **A1 / C6-1,D7-1,Z8-1,I9-1,B9-C1:** explicit permanent exit cancellation, native tracking plus common-mode fine timer, named idempotent cancellation/tick entries, exact panel opacity-hide/orderOut/close and button disable/detach/hide hooks. Deterministic tests must exercise actual dispatch after cancellation.
- **A2 / I9-2,B9-C2:** main-thread unstarted-manager/panel tests; no physical boost; deferred cleanup and effective-value then original-domain restoration, including missing-key presence.
- **A3 / I9-3:** ordered implementation phases with test/build checkpoints and final local/remote acceptance gates.
- **A4 / D7-2,Z8-2:** compare AppKit continuous action to native tracking plus explicit fine timer; keep AppKit tracking and avoid a custom event loop.
- **A5 / C6-2,T7-1,T9-1,T9-2:** link/define workflow names, clarify cap and neutral floor, separate accessible naming from appearance and split SPEC instructions.

Implementation and verification evidence is recorded in `implementation_evidence.md`: all Goldfish actions and both later Impeccable findings are implemented; the final checkpoint passes 49 tests and builds successfully. No finding is treated as evidence of physical luminance, VoiceOver or rendered contrast acceptance.
