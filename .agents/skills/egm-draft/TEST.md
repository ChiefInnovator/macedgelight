# Test Plan: EGM Draft Skill

This is a manual behavioral checklist. The upstream `pytest tests/unit` harness is not installed here; see [upstream TESTING.md](https://github.com/google/elephant-goldfish-model/blob/403d8881d62022490637d740657b33f01e321ea8/TESTING.md). For supported local integrity checks, see [installation scope](../../INSTALLATION.md#local-checks).

## Protocol Verification Checklist

When evaluating or exploring `egm-draft` interactively in chat, verify:

-   **Step 4 (Alternatives):** Reads rejected alternatives from the brief's
    `Alternatives Weighed` section, or asks the user if it is absent.
-   **Step 6 (Finalize):** Reports contradictions between the brief and the
    draft before directory selection, and waits for the user to decide each
    one. Does not self-grade against
    the Zoom Out standard.
