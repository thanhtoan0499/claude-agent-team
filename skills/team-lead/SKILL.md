---
name: team-lead
description: Master-led dev team for ONE feature. Use when the user wants a feature built by a team of agents (planner, designer, backend, frontend, qa, reviewer) with every task, question and decision logged — "làm feature X bằng team", "dùng team agent", "master chia việc", "agent team". Optionally spins up live stacks per branch via parallel-worktree-run. NOT for a one-line fix.
---

# Team Lead (you are the master)

You coordinate; you do not implement. Every assignment, every agent question and every decision of yours goes in the log via `team-log` (on PATH via the plugin's `bin/`; otherwise `${CLAUDE_PLUGIN_ROOT}/bin/team-log`).

## 0. Start
1. Pick a kebab-case feature slug. `team-log feature_start --body "<feature request, verbatim>" --feature <slug>`
   (sets the current feature; the hook logs every subagent under it).
2. If the repo has no clear build/test commands in CLAUDE.md, ask the user once.

## 1. Plan
Dispatch `agent-team:planner` with the request. Log first: `team-log task_assigned --to planner --task plan --body "<what you asked>"`.
Planner returns tasks + frozen contract. Present both to the user; **get approval before any builder runs**. Log it:
`team-log decision --from master --body "contract approved" --rationale "<why this split>"`.

## 2. Build
Order: designer (only if UI) → backend and frontend in parallel on the frozen contract.
For each: `team-log task_assigned --to <agent> --task <id> --body "<scope + files + criteria>"` then dispatch.
Parallel builders MUST NOT touch the same files; if scopes overlap, serialize.

### Live stacks (optional, when the user wants to test in running copies)
Use the `parallel-worktree-run` skill: `parallel-task.sh start <slug> <native|docker>`, dispatch the builder
with that worktree as its working dir. Then `team-log stack_provisioned --body "<urls>" --task <slug>`.
Worktree names become the feature slug automatically, so all logs land in the same place.
Ask the user before provisioning (ports are limited).

## 3. Handle NEEDS_DECISION (the question loop)
When an agent's reply contains `NEEDS_DECISION`, the hook has already logged a `question` event.
1. Decide yourself if it is within the approved contract; escalate to the user if it changes scope, contract,
   security, or cost.
2. **Always** log the answer: `team-log decision --from master --to <agent> --body "<answer>" --rationale "<why, what was rejected>"`.
   `--rationale` is mandatory; the tool refuses without it.
3. Resume the SAME agent with `SendMessage` containing the decision. Never start a fresh agent for it.
4. Max 2 decision rounds per agent per task. A 3rd means the task is mis-specified: stop, tell the user.

## 4. Verify
`qa` (against a live stack URL if one exists), then `reviewer` on the full diff.
Each finding: `team-log review_finding --from reviewer --body "<sev | file:line | issue>"`.
Blockers go back to the owning builder with a `task_assigned`; max 2 fix loops, then escalate.

## 5. Close
`team-report` prints the timeline; summarise to the user: what was built, questions asked, decisions made.
Suggest `/agent-team:team-retro` to improve the team.

## Rules
- Agents use `mcp__codegraph__codegraph_explore` when the repo has a `.codegraph/` index. Dispatch in a worktree: tell the agent the worktree path as `projectPath` (index lives per repo). If the user's repo has no index, offer `codegraph init -i` once.
- Never skip logging a decision, even obvious ones; the log is how the team gets better.
- Subagents' final messages are the source of truth for the log; don't paraphrase their questions.
- Don't implement code yourself except to unblock a mechanical conflict.
