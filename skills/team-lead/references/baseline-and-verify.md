# Baseline and verify — what was red before us, and the green check before a PR

Two rules the user set (2026-10-02):
1. A check that is already red on the base is **not** an implementation failure. Fix it if you can, report it **once** at the end.
2. No PR until the repo's verify suite passes, run on the right number of cores.

## Cores
`team-cores` prints the worker count for this box right now: `nproc - ceil(1-min load)`, min 2, max nproc (`--explain` says why).
Every parallel runner in baseline and verify gets it explicitly, never `auto`:
pytest `-n <w>` (replaces `-n auto` / `-n <workers>` in the repo's steps), vitest `--maxWorkers=<w>`, playwright `--workers=<w>`.
Put the number in the brief; the agent re-runs `team-cores` only if the run starts much later.

## Find the repo's verify suite (step 0, with the other repo facts)
First match wins: `.claude/skills/verify/SKILL.md` → `.claude/commands/verify.md` → a `verify`/`check` target in Makefile /
package.json / CLAUDE.md. Subagents cannot call skills: the brief gives the FILE PATH and says "run its steps in order".
None found: verify = the test, lint and typecheck commands CLAUDE.md names for the layers the plan touches. Log which one as a `note`.

## Baseline (step 2, before any builder edits)
Who: `qa`, in the workspace the builders will use, while it is still the untouched base commit (designer may run in parallel; it does not edit).
What: the verify suite + every existing test file the plan names (e2e specs included, they are often not in verify).
Output: `.team-log/<feature>/baseline.md` (absolute path in the brief, it lives in the MAIN repo root) with the base commit, each
command + exit code + counts, and one line per red check: `<check id> | <first error line> | root cause if obvious`.
Log it: `team-log baseline --verdict CLEAN|RED --body "<base sha>; <commands>; red: <ids or none>"`.
For a bug ticket, the same qa dispatch then writes task 0 (the failing test): one dispatch, baseline first.

### Red baseline: fix if you can, without asking
Standing rule from the user, so it is `decided_by policy`, no gate and no question:
`team-log decision --from master --decided-by policy --body "fix baseline: <ids>" --rationale "standing rule: red base is fixed when possible, reported at the end"`.
- A separate task `B<n>` with its own TERRITORY (usually test mocks/fixtures/config) and its own commit `fix(test): ...`.
  It never shares files with a ticket task running at the same time.
- Limits: reversible, inside the working tree, not security/auth/tenant, no migration, no new dependency. Outside these, do not
  fix: list it for the end report.
- One builder round (R1) only. Still red → stop trying, keep it in `baseline.md` as `unfixed: <why>`. Never let it block the ticket.

### Classifying red checks later
qa and reviewer tag every red check `NEW` or `BASELINE` against `baseline.md` (same check id, same failure). Only `NEW` counts
against the implementation and enters the fix loop. A `BASELINE` check that turns green is a bonus to report, not a finding.
Do not tell the user about baseline mid-run; it goes in the one end report.

## Verify before PR (step 5)
1. `qa` runs the full verify suite in the workspace with `team-cores` workers. Long suites: run in the background and poll the
   output file, as the repo's verify file says. One command per Bash call: `uv run --directory libs/core pytest ...`,
   `pnpm --dir apps/web ...` instead of `cd x && y`; a worktree-isolated agent refuses compound commands.
2. PASS = every step exit 0, or red only on checks that are `BASELINE` + `unfixed` in `baseline.md` (named in the report).
   Any `NEW` red → escalation ladder (R1 owning builder), then verify again. No PR on a verify you did not see pass this round.
3. Repo PR rules next (e.g. a `pr-doc` / `pr-rules-check` skill or `docs/pr/` convention): follow them before the question.

## The one end question
After verify PASS, ONE `AskUserQuestion` carrying the end report:
built / decided by you / decided by the user / assumptions / **Baseline** (red on base: fixed in `<commit>`, still red + why) /
verify evidence (commands, exit codes, counts, workers used). Options:
`Commit + push + draft PR (Recommended)` / `Commit only, I push` / `Stop, I review the diff first`.
Approval = their answer. Then commit (repo's commit format), push, open the PR as a draft with `gh pr create --draft`: the hook logs `pr` + `feature_end`
from it. "Commit only" / "Stop": log `feature_end` yourself with what was left.
