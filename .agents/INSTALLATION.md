# Project-local design runtime

- EGM: Google [elephant-goldfish-model](https://github.com/google/elephant-goldfish-model/tree/403d8881d62022490637d740657b33f01e321ea8), pinned revision `403d8881d62022490637d740657b33f01e321ea8`. Seven skills are under `.agents/skills/egm-*`; personas, standards, and host guides are under `.agents/agents`, `.agents/resources`, and `.agents/docs`. See `egm-source.json` for local patches. Apache-2.0 notices remain intact.
- Impeccable: skill 4.8.0, engine 0.1.18, installed under `.agents/skills/impeccable` using the command recorded in `impeccable-source.json`. The launcher pins the engine/checksums; generated binary/cache state is ignored. This npm installation records released versions, not an upstream Git commit. Local desktop patches are listed separately in provenance.

## Runtime scope

Use the discovered project-local SKILL.md paths. EGM root-relative persona and standard paths resolve against `.agents/`, not the repository root. Artifact paths resolve against the working directory; this repository uses `docs/design` as specified in AGENTS.md. Read `.agents/docs/codex.md` for fresh-context dispatch and question-tool adaptation. A missing fresh-context subagent capability stops a Goldfish review; sequential same-context roleplay is not a substitute.

The review-loop resolver accepts filename shortnames; registered persona frontmatter names are host identities, not resolver keys:

| Resolver key | Persona file | Host name |
| --- | --- | --- |
| design_critic | agents/design_critic.md | egm-design |
| structural | agents/structural.md | egm-structural |
| style | agents/style.md | egm-style |
| implementation_readiness | agents/implementation_readiness.md | egm-implementation-readiness |
| codebase_details | agents/codebase_details.md | egm-codebase-details |
| comprehension | agents/comprehension.md | egm-comprehension |
| zoom_out | agents/zoom_out.md | egm-zoom-out |

Impeccable's upstream native playbooks target mobile. The local `reference/macos.md` route supports source-based AppKit design work and reviews with explicit desktop verification limits. It bypasses engine platform guesses and web/mobile tooling for desktop targets. It does not add an AppKit detector, browser editing support, or automated native visual/hardware acceptance. A separately scoped website can use the web route.

## Development documentation scope

Vendored EGM design/release/package documents describe the upstream project. `scripts/pack_plugin.py`, `tests/unit`, `TESTING.md`, host plugin manifests, and `distributions/claude` are not installed in this repository. Run their packaging/release instructions only in a separate checkout of the pinned upstream source; links in local test plans point there. No plugin ZIP is built from this runtime installation. The local `TEST.md` files and YAML scenarios are manual/model behavioral specifications; an upstream evaluation runner is not included, and fixture existence is not proof of model behavior.

## Local checks

From the repository root:

```sh
python3 .agents/scripts/check-installation.py
git diff --check
```

The offline standard-library check validates JSON, actual Stage 7/9 reviewer and standard resolution, worker required-array schema structure, the seven skill/icon files, scenario fixture paths/intake completeness, and desktop routing guards. It does not run model-driven behavioral evaluations, prove host picker rendering, or exercise the engine. For Swift implementation changes use `make test` and `make build`; native visual and hardware acceptance remains separate under `docs/SPEC.md`.
