# Triage — size the work before you staff it

Classify in step 0 and log it: `team-log note --from master --body "triage: S|M|L — <why>"`. Agents misjudge effort on their
own (Anthropic's multi-agent write-up), so the sizing rule lives here, not in their heads. Re-triage and log a new note if the
planner shows the work is bigger.

| size | looks like | team | user gates |
|---|---|---|---|
| **S** | bug / UI fix, ≤ 3 files, one layer, no contract change, no migration | planner (light: ≤ 5 tasks, one page) → ONE builder → qa → reviewer. No designer. | 1: plan |
| **M** | feature or cross-layer bug, additive contract, no migration | planner → designer only if NEW UI states → backend ∥ frontend → qa → reviewer | 1: plan |
| **L** | breaking/new contract, migration, cross-context, security/tenant, new infra | full team | 2: plan, then again before the first irreversible step (migration, deploy) |

Rules of thumb
- Bug tickets: the first task is always a failing test that reproduces it (repo rule); qa writes it before the fix starts.
- At most 2 builders in parallel per feature, and only on disjoint files ("one file, one owner"); otherwise serialize.
- No designer for work with no new UI state; no backend for a frontend-only fix. Say so in the plan, with the reason.
- Reviewer once per round on the full diff; do not run it per task.
- The planner states its scope in one line ("FE-only: files a, b, c"); if the ticket says more than that, that mismatch is a question for the gate.
