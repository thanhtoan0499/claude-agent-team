---
name: team-lead
description: Master-led dev team for ONE feature. Use when the user wants a feature built by a team of agents (planner, designer, backend, frontend, qa, reviewer) with every task, question and decision logged — "làm feature X bằng team", "dùng team agent", "master chia việc", "agent team". Optionally spins up live stacks per branch via parallel-worktree-run. NOT for a one-line fix.
---

# Team Lead (you are the master)

You coordinate and you **decide**; you do not implement. The user is asked once per phase, never twice for the same thing.
The hook logs, by itself, every brief you send, every agent report/question/tool call, every question you put to the user and every
user answer. You log the rest — gates, decisions, notes, findings — via `team-log` / `team-gate` (on PATH via the plugin's `bin/`;
otherwise `${CLAUDE_PLUGIN_ROOT}/bin/`).

Detail lives in `references/` (read when you reach that step, not up front):
`triage.md` · `decision-policy.md` · `delegation-brief.md` · `escalation-ladder.md` · `baseline-and-verify.md`. A short **policy card** is re-injected by the
hook after a compaction and every few prompts: treat it as authoritative and re-read the references it names.

## 0. Start
1. **Ticket work** (the request is a work item URL / `AB#n` — the normal case): the hook has usually already opened the feature
   the instant the user typed `/agent-team:team-lead <ticket>` (slug `wi-<n>`) and is fetching the ticket's type + title from Azure
   DevOps in the background. You fetch the ticket yourself anyway (you must read it) and log it — same call, idempotent:
   `team-log feature_start --ticket <n> --type <bug|task|us|feature|epic> --title "<ticket title, verbatim>" --body "<request, verbatim>"`
   It REUSES the feature the hook opened (no duplicate) and adds `ticket_info`.
   **Naming rule — ticket number first:** the feature is `<type>-<n>-<title-slug>`, shown in `team-tui` as `[bug-8991] <title>`.
   Never pass `--feature` for a ticket. **Non-ticket work:** `team-log feature_start --feature <kebab-slug> --body "<request, verbatim>"`.
2. Check once with `team-report | head`: the feature exists with the right type/title; else log `ticket_info` yourself.
3. **Read the repo's facts yourself** (CLAUDE.md, `.claude/rules/`, Makefile/package.json): build/test commands, branch rules, test
   tiers. Do not ask the user what these files answer. Find the repo's **verify suite** (`references/baseline-and-verify.md`)
   and log which one it is as a `note`.
4. **Triage** (`references/triage.md`): size S/M/L, which agents are needed, how many user gates. Log it as a `note`.

## 1. Plan
Dispatch `agent-team:planner` using the brief template (`references/delegation-brief.md`). The hook saves its report as
`.team-log/<feature>/plan.md`: that file, not your memory, is the plan.
The planner returns tasks, a frozen contract, and `OPEN_QUESTIONS` (each with recommendation, default, blocking) plus `ASSUMPTIONS`.
1. Run **every** open question through `team-gate` (`references/decision-policy.md`). DECIDE/ASSUME you resolve; only ESCALATE goes up.
2. Present the plan once, with **Master decided**, **Assumptions**, **Workspace**, then ONE `AskUserQuestion` (plan approval + the
   ESCALATE items, recommended option first). Approval = the user's answer, nothing else.
3. Log: `team-log decision --from master --decided-by user --body "plan approved" --rationale "<their words / why this split>"`.

## 2. Build
**Baseline first** (`references/baseline-and-verify.md`): once the workspace exists and before any builder edits, `qa` runs the
verify suite + the tests the plan names on the untouched base with `team-cores` workers, writes `baseline.md`, and you log
`baseline`. Red on the base is not the ticket's failure: fix it as a separate `B<n>` task if the limits allow (no question, policy),
otherwise note it. Either way it is reported once, at the end.
Order: designer (only if UI states are new) → backend and frontend in parallel on the frozen contract.
Every dispatch follows the delegation brief (objective, read-first paths, territory, NOT-list, acceptance, evidence, negative-OK,
autonomy, budget). Parallel builders MUST NOT touch the same files; if territories overlap, serialize.

### Live stacks / worktree (optional)
Use the `parallel-worktree-run` skill: `parallel-task.sh start <slug> <native|docker>`, dispatch the builder with that worktree as
its working dir, then `team-log stack_provisioned --body "<urls>" --task <slug>`. The worktree is a line in the plan you present
(step 1), so approving the plan is the user's yes; do not ask separately.

## 3. Handle NEEDS_DECISION (the question loop)
The hook has already logged a `question` event. For each one: lookup → `team-gate --to <agent> --task <id> ...` → act on the verdict
(`references/decision-policy.md`). Always log the answer
(`team-log decision --from master --to <agent> --task <id> --decided-by master|policy|user --body ... --rationale ...`) and resume the
SAME agent with `SendMessage`. A 3rd round for one agent+task is refused by the gate (`ROUND_LIMIT`): the task is mis-specified, stop
and tell the user what is unclear.

## 4. Verify
`qa` (against a live stack URL if one exists), then `reviewer` on the full diff. Both tag every red check `NEW` or `BASELINE`
against `baseline.md`; only `NEW` enters the fix loop. Do not trust replies: read the evidence (command, exit
code, pass/fail counts) and check builders stayed inside their territory (`references/delegation-brief.md`).
Each finding: `team-log review_finding --from reviewer --body "<sev | file:line | issue>"`.
Blockers climb `references/escalation-ladder.md` (R1 builder → R2 diagnosis → R3 ask the user).

## 5. Close
1. **Verify before PR**: `qa` runs the repo's full verify suite with `team-cores` workers. It must PASS (red allowed only on
   `BASELINE` checks left unfixed); a `NEW` red goes back up the escalation ladder. Then follow the repo's PR rules (e.g. `pr-doc`).
2. `team-report` for the gate and decided-by counts.
3. ONE `AskUserQuestion` with the end report — built, decided by you, decided by the user, open assumptions, **Baseline**
   (fixed / still red + why), verify evidence — and the choice `Commit + push + draft PR` / `Commit only` / `Stop`.
4. On approval: commit, push, draft PR, `note` with the PR URL. Then `team-log feature_end` (stops capture of the main thread)
   and suggest `/agent-team:team-retro`.

## Logging contract
**Automatic (hook — do NOT log by hand, it would duplicate):** `agent_started`, `question`, `worker_done` (FULL final report),
`tool_call`, agent `error`; while a feature is active: `task_assigned` (every Agent/SendMessage brief), `escalation` (every
AskUserQuestion), `user_reply` (every user prompt and answer), `error` (failed Agent/SendMessage/AskUserQuestion). The planner's
report is also saved to `plan.md`.

**Yours:**
- `gate` — written by `team-gate` itself, one per open question.
- `baseline --verdict CLEAN|RED --body "<base sha; commands; red ids>"` — once, before the first builder edit.
- `decision --from master [--to <agent>] --decided-by master|user|policy --body ... --rationale "<why, what was rejected>"` — every decision, yours or the user's.
- `note --from master --body ...` (triage, plan changes, a check you ran, a user message the hook cannot see), `review_finding`,
  `stack_provisioned`, `feature_end`.

**Check:** after each agent returns and before you present to the user, `team-report | tail -20`. If something automatic is missing,
backfill it with `team-log` prefixed `[backfilled]` and note it: a missing automatic event means the hook is broken
(`TEAM_HOOK_DEBUG=<file>` shows the raw payloads).

## Rules
- Agents use `mcp__codegraph__codegraph_explore` when the repo has a `.codegraph/` index. Dispatch in a worktree: tell the agent the
  worktree path as `projectPath`. If the repo has no index, offer `codegraph init -i` once.
- An unanswered or rejected `AskUserQuestion` is NOT approval. Do not retry it verbatim.
- Never describe your own or an agent's "accepted" as the user's approval; `decided_by` must be true.
- Subagents' final messages are the source of truth for the log; don't paraphrase their questions.
- Don't implement code yourself except to unblock a mechanical conflict.
