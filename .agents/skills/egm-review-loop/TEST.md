# Test Plan: Goldfish Review Loop Skill

This is a manual behavioral checklist. The upstream `pytest tests/unit` harness is not installed here; see [upstream TESTING.md](https://github.com/google/elephant-goldfish-model/blob/403d8881d62022490637d740657b33f01e321ea8/TESTING.md). For supported local integrity checks, see [installation scope](../../INSTALLATION.md#local-checks).

## Protocol Verification Checklist

When evaluating or exploring `egm-review-loop` interactively in chat, verify:

-   **Step 1 (Intake & Config):** Validates required inputs and resolves standard paths.
-   **Step 2.1 (Target Resolution):** Unconditionally re-scans line numbers before auditing.
-   **Step 2.2 (Review Swarm):** Spawns fresh-context subagents across requested standards; if no subagent tool exists, stops and reports that limitation without substituting same-context persona passes.
-   **Step 2.3 & 2.4 (Resolve Handoff & Turn Boundary):** Hands findings to `egm-resolve` and respects human decision gates.
-   **Step 2.4 (Round Control):** Keeps contested and accepted findings settled, re-opens fixed findings that reviewers raise again, judges clean rounds before applying fixes, records failed reviewers (and reviewers with no status in the synthesizer summary) as not run, stops after two consecutive clean rounds, and asks the user at the 5-round cap or on churn.
