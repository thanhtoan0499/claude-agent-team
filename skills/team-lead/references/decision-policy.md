# Decision policy — the master decides; the user is a scarce resource

The user is asked **once per phase**, and only for what only they can answer or what cannot be undone.
Everything else you decide, log, and show as an assumption they can veto with one click.
(Pattern sources: coscc "a gate is code, not mood"; devjarus "only the orchestrator asks, in ONE question";
Osmani "plan approval is cheap, bad code is not".)

## Procedure for every open question
(planner `OPEN_QUESTIONS` item, agent `NEEDS_DECISION`, or a fork you hit yourself)

1. **Look it up first.** CLAUDE.md, `.claude/rules/*`, Makefile / package.json / pyproject, the ticket's acceptance
   criteria, the code (codegraph). If a repo rule answers it: `team-log decision --decided-by policy` citing the file. No gate needed.
   Never ask the user for: build/test/lint commands, branch naming, commit format, test tiers, anything a rule file states.
2. **State five facts and run the gate** (do not skip it for "obvious" cases, the log is how the team gets better):
   ```
   team-gate --topic "<question>" --in-ticket y|n --reversible y|n --external y|n --security y|n --needs-human y|n \
             [--placeholder y|n] [--to <agent> --task <id>]
   ```
   | fact | answer `y` when |
   |---|---|
   | in-ticket | the answer stays inside the ticket's acceptance criteria / the approved contract |
   | reversible | undoing it is a code edit (not a migration, push, deploy, deleted data) |
   | external | it acts outside the working tree: git push, PR, ADO/Jira write, deploy, prod data, spend, paid API |
   | security | auth, tenant isolation, secrets, permissions, PII |
   | needs-human | the answer exists only in someone's head: BA copy, a business rule, a customer choice |
   | placeholder | (with needs-human) work can proceed on a clearly flagged stand-in, e.g. an i18n key + draft text |
3. **Act on the verdict** (stdout line 1; exit 0 = DECIDE/ASSUME, 1 = ESCALATE):
   - `DECIDE` — decide now. `team-log decision --from master [--to <agent>] --decided-by master --body ... --rationale "<why; what was rejected>"`,
     resume the asking agent with `SendMessage`.
   - `ASSUME` — proceed on the placeholder; it goes under ASSUMPTIONS in the plan you present.
   - `ESCALATE` — goes into the one batched question below. Never ask it alone. Codes tell you why:
     `OUT_OF_SCOPE`, `IRREVERSIBLE`, `EXTERNAL_EFFECT`, `SECURITY`, `NEEDS_HUMAN_INFO`, `ROUND_LIMIT`.

## The one gate (batching)
Before any builder runs, present in text: the tasks + contract, then three lists — **Master decided** (DECIDE items with
one-line reason), **Assumptions** (ASSUME items, flagged), **Workspace** (worktree/branch you will create; approving the plan is
the user's yes that the repo's worktree rule asks for). Then make ONE `AskUserQuestion`:

1. Plan approval: `Approve (Recommended)` / `Change something` / `Stop`.
2. up to 3 more questions, one per ESCALATE item, **recommended option first**, the reason in each option's description.

More than 3 ESCALATE items means the planner under-specified the ticket: send it back once with the list instead of asking the user.
If the user rejects or interrupts the question, you have NO approval: do not re-ask the same questions; ask one short plain-text
question about what they want to change, and wait.

## After the answer
Log every answer: `team-log decision --from master --decided-by user --body "<their choice>" --rationale "<their reason, or 'user choice'>"`.
Then proceed. Never re-ask something the user already answered; never describe your own or an agent's "accepted" as the user's approval.

## Always escalate (no gate can lower these)
git push / PR / merge, writes to ADO, deploy, migration on a shared environment, deleting user data or branches, spend,
widening scope past the ticket's acceptance criteria, any change to the auth/tenant model.

## Limits
- Max 2 decision rounds per agent per task (`team-gate --to <agent> --task <id>` enforces it with `ROUND_LIMIT`). A 3rd means
  the task is mis-specified: stop and tell the user what is unclear.
- `decided_by` is evidence. `master` = your judgement, `policy` = a repo rule, `user` = the user chose. Never mislabel.
