# Protected branch workflow

Changes flow `feature/<name>` → `develop` → `main`, using pull requests and merge commits.
Both source branches must be in `ChiefInnovator/macedgelight`; forks must first be imported to a feature branch.
A feature name must be nonempty after `feature/`.

## Enforcement

Active rulesets have no bypass actors, including administrators. They require a pull request,
resolved review threads, and passing GitHub Actions checks named `Branch source policy` and
`check-version`. Strict status checking requires the source to be current with its target.
Deletion and force pushes are blocked. Zero human approvals are required for this solo-developer
repository; automatic Copilot feedback and required checks remain separate controls.

The branch-source workflow uses `pull_request_target` so the trusted base owns its validation.
It checks only event metadata, has read-only contents permission, and never checks out or
executes source-branch code. It reruns when the source updates or the PR target changes.
Protect this workflow when reviewing future changes: a repository administrator can still
edit rulesets, and a maintainer can propose changes to the trusted workflow through this process.

Copilot automatic cloud code review is scoped to `refs/heads/develop`, including draft PRs and
new pushes. No rule requests Copilot review on `main`. Personal account settings can separately
request reviews; repository rules cannot override those settings. Never manually request reviews.

## Daily use

```sh
git switch develop
git pull --ff-only origin develop
git switch -c feature/my-change
# edit, check, commit
git push -u origin feature/my-change
gh pr create --base develop
```

Monitor automatic reviews and checks. Address findings with real commits, resolve threads after
fixing them, and merge with `gh pr merge --merge`. Do not rebase. If the source is behind its base,
merge the target into the source and push. Never delete `develop` after promotion.

For promotion, create a `develop` → `main` PR. Merge `main` back into `develop` through a
`feature/*` synchronization branch if a later change needs the promotion merge in its ancestry.
The default branch remains `main`; GitHub Pages and published releases remain tied to main.

## Bootstrap and recovery

PR #2 installed the trusted workflow through `develop` → `main` before mandatory source checks
were activated. This one-time bootstrap completed before either protected branch accepted further work.
Rulesets: Copilot `21801552`, main `26362064`, develop `26362065`.

If a required job is missing, repair its trusted workflow through the same allowed PR path.
Do not add an administrator bypass or disable protection as routine recovery. GitHub service
outages can delay merges; a green local check does not substitute for a required remote check.

## Verification evidence (2026-11-02)

- PR #3, feature → develop: `Branch source policy` passed in run `41438262154`.
- Same PR retargeted feature → main: policy failed in run `41438353555`; GitHub reported `BLOCKED`.
- Retargeted back to develop: policy passed in run `41438439500`. No test PR was merged.
- The exact workflow shell predicate passed 12 local cases: allowed promotion/feature sources,
  nested feature names, empty feature name, wrong source branches, forks, and unexpected targets.
- GitHub readback showed source policy/version requirements on both branches, no bypass actors,
  and the Copilot rule only on develop. Required checks were visible on the real PR.
- Baseline `make test`: 45 tests passed; `make build`: succeeded. These do not prove display hardware behavior.
