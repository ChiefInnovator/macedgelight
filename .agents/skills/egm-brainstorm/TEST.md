# Test Plan: EGM Brainstorm Skill

This is a manual behavioral checklist. The upstream `pytest tests/unit` harness is not installed here; see [upstream TESTING.md](https://github.com/google/elephant-goldfish-model/blob/403d8881d62022490637d740657b33f01e321ea8/TESTING.md). For supported local integrity checks, see [installation scope](../../INSTALLATION.md#local-checks).

## Protocol Verification Checklist

When evaluating or exploring `egm-brainstorm` interactively in chat, verify:

-   **Step 1 (Open-Ended Clarification & Gate):** Drills down into half-baked concepts
    using open-ended chat questions (without structured question tools or multiple-choice lists)
    and enforces a user readiness checkpoint gate before subagent invocation.
-   **Step 2 (Upstream Multi-Lens Ideation):** Evaluates feature concepts across the
    6 specialized Goldfish perspective lenses (Contrarian/YAGNI, Cost/Quota Economics,
    UX Ergonomics, Migration & Compatibility, Observability & SRE, Tech Debt & Maintenance).
-   **Step 3 & 4 (Concepts Brief Deliverable & Handoff):** Compiles and saves the
    synthesized `concepts_brief.md` artifact for user review and handoff to
    `/egm-draft`.
