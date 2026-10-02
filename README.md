# agent-team

Master-led AI dev team for Claude Code. One feature → planner, designer, backend, frontend, qa, reviewer,
with a structured log of every task, question and decision. Pairs with
[`parallel-worktree-run`](https://github.com/thanhtoan0499/claude-parallel-worktree-plugin) for a live stack per branch.

## Install
```
/plugin marketplace add thanhtoan0499/claude-agent-team
/plugin install agent-team@agent-team-marketplace
```
Requires `jq` and `git`. Put `bin/` on PATH (or call `${CLAUDE_PLUGIN_ROOT}/bin/team-log`).

## Use
Tell Claude: "dùng team làm feature X" → skill `team-lead` (you = master).

Flow: `planner` (contract, you approve) → `designer` → `backend` ∥ `frontend` → `qa` → `reviewer`.
Agents never guess: they end with `NEEDS_DECISION` (question + options + recommendation); the master answers
with a **mandatory rationale** and resumes the same agent via `SendMessage`. Max 2 rounds, then escalate.

## Log
`<repo>/.team-log/<feature>/events.ndjson`, one JSON per line. Worktrees share the main repo's log; the
worktree name is the feature slug.

| type | written by |
|---|---|
| `feature_start`, `task_assigned`, `decision`, `stack_provisioned`, `review_finding` | master via `team-log` |
| `agent_started`, `worker_done`, `question` | `SubagentStart/Stop` hook (a `NEEDS_DECISION` reply becomes `question`) |

```
bin/team-tui                  # lazygit-style: left = tickets, Enter = timeline (agents, questions, decisions+WHY)
bin/team-report [feature]     # timeline: who asked what, what master decided and WHY
/agent-team:team-retro        # find repeated questions / reversed decisions → improve agent prompts
bash tests/test_log.sh        # self-check
```
`team-tui` keys: j/k move · enter open · f Q&A-only · G follow · g/PgUp/PgDn scroll · esc back · q quit.
NDJSON is the source of truth; `.team-log/team.db` (SQLite) is a derived index rebuilt incrementally, safe to delete.

`team-log` refuses a `decision` without `--rationale`, a `question` without `--from`, a `task_assigned` without `--to`/`--body`.

## Not yet (v0.1)
- Agents picking tasks from a board (direction 1).
- Decisions by a master that is a separate headless agent (today the master is your main session).
- Langfuse/OTel export (NDJSON → OTLP is a small converter).
