## What this proposes

The design proposes restoring fine adjustment while holding six HUD buttons, limiting automatic menu-bar reveal to the overlay’s own display, adding explicit accessibility names, and completing shortcut help. It preserves the existing appearance, rendering, settings, and brightness-boost lifecycle. It also updates product documentation, installs local design/review tooling, and establishes protected feature→develop→main delivery.

## How the existing system works, per this document

MacEdgeLight is an AppKit menu-bar application whose manager connects persisted settings to screen overlays, HUD/menu/keyboard controls, and independent tools. Overlays draw and animate the ring light; display brightness boost uses separate EDR signaling and gamma management with lifecycle recovery. The current code already contains fine adjustment actions, but ordinary HUD buttons cannot invoke them through holding. Tests and source inspection cover selected behavior; interactive accessibility, display behavior, and server-side delivery enforcement require separate verification.

## Findings

### C6-1 — Nit: Pointer-exit behavior is unspecified
Affected: `design_draft.md:97,113,174`. The design requires pointer-exit testing without defining whether leaving stops, pauses, or continues repetition. State pointer-exit/reentry behavior beside the hold contract and use the same expectation in verification.

### C6-2 — Nit: Workflow names lack definitions or entry links
Affected: `design_draft.md:12,32,165–166`. Define EGM/Goldfish and Impeccable briefly and link their local entry instructions near first introduction.

No Blocker or Major findings; both parts can be paraphrased coherently.

## Review evidence
Reviewer `/root/goldfish_pipeline/comprehension`, fresh context (`fork_turns: none`), read complete `.agents/agents/comprehension.md` and complete 182-line target. Reviewed feature 1–151 and implementation 152–182; checked rest of target for definitions. No standard applies. No additional referenced files needed for comprehension. No writes, builds, tests, memory, or subagents used.
