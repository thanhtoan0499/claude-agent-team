# agent-team

Master-led AI dev team for Claude Code. One feature → planner, designer, backend, frontend, qa, reviewer,
with a structured log of every task, question and decision. Pairs with
[`parallel-worktree-run`](https://github.com/thanhtoan0499/claude-parallel-worktree-plugin) for a live stack per branch.

## Install
```
/plugin marketplace add thanhtoan0499/claude-agent-team
/plugin install agent-team@agent-team-marketplace
```
Requires `jq` and `git`. Optional: the `codegraph` MCP server; agents then use `codegraph_explore` for code questions and fall back to grep without it. Put `bin/` on PATH (or call `${CLAUDE_PLUGIN_ROOT}/bin/team-log`).

## Use
Tell Claude: "dùng team làm feature X" → skill `team-lead` (you = master).

Flow: `planner` (contract, you approve) → `designer` → `backend` ∥ `frontend` → `qa` → `reviewer`.
Agents never guess: they end with `NEEDS_DECISION` (question + options + recommendation); the master answers
with a **mandatory rationale** and resumes the same agent via `SendMessage`. Max 2 rounds, then escalate.

## Naming: ticket number first
A feature that tracks a ticket is named `<type>-<ticket>-<title-slug>` (e.g. `bug-8991-fe-serving-activate-version-moi-ghi-de-admin-layout`)
and `team-tui` shows it as `[bug-8991] <title>`, so tickets are easy to scan and pick. Older logs without metadata are labelled from the
number in their slug (`[8991] name`). `team-log feature_start --ticket N [--type T] [--title X]` builds the name and reuses the feature that
already tracks ticket N.

**Hook + agent in parallel:** typing `/agent-team:team-lead <ADO URL | AB#n>` makes the hook open the feature immediately (exact id, no LLM
involved) and spawn `bin/team-ticket`, which fetches the type and title from Azure DevOps (`az boards`, ~2 s, detached so the prompt is never
delayed; org from the URL or `TEAM_ADO_ORG`). Meanwhile the master reads the ticket and logs the same metadata (`ticket_info`); the TUI shows
the latest. If `az` is missing or not logged in, the master's entry is the only source.

## Log
`<repo>/.team-log/<feature>/events.ndjson`, one JSON per line. Worktrees share the main repo's log; the
worktree name is the feature slug.

| type | written by |
|---|---|
| `feature_start`, `feature_end`, `ticket_info`, `decision`, `review_finding`, `stack_provisioned`, `note` | master via `team-log` |
| `agent_started`, `worker_done`, `question` | `SubagentStart/Stop` hook. Body = the agent's FULL final report (read from the subagent transcript when the agent ends via `SubagentHandback`); a `NEEDS_DECISION` line makes it a `question`; `ref` = path of the agent's transcript |
| `tool_call`, `error` | `PostToolUse` / `PostToolUseFailure` hook for agent-team agents (one line per call) |
| `task_assigned` (master's brief), `escalation` (question to the user), `user_reply` (user prompt / answer), `error` (failed Agent/SendMessage/AskUserQuestion) | main-thread hooks (`PreToolUse` Agent/SendMessage/AskUserQuestion, `UserPromptSubmit`, `PostToolUse(Failure)`), **only while a feature is active**: `.team-log/CURRENT` set by `feature_start`, refreshed by every event, expires after 12 h idle, cleared by `feature_end` |

Appends are serialised with `flock` (parallel agents with large bodies would otherwise interleave lines). Timestamps carry milliseconds where GNU `date` supports it.

`TEAM_HOOK_DEBUG=/tmp/hook.ndjson` appends every raw hook payload to that file, for diagnosing a missing event.

```
bin/team-tui                  # lazygit-style: left = tickets, Enter = timeline (agents, questions, decisions+WHY)
bin/team-report [feature]     # timeline: who asked what, what master decided and WHY
/agent-team:team-retro        # find repeated questions / reversed decisions → improve agent prompts
bash tests/test_log.sh        # self-check
```
`team-tui` keys: j/k move (list) or scroll (inside a ticket) · space/b page · g/G top/end · n/p next/prev ticket · c copy timeline (wl-copy, xclip, else OSC52) · f Q&A-only · enter open · esc back · q quit.
NDJSON is the source of truth; `.team-log/team.db` (SQLite) is a derived index rebuilt incrementally, safe to delete.

`team-log` refuses a `decision` without `--rationale`, a `question` without `--from`, a `task_assigned` without `--to`/`--body`.

## Not yet (v0.1)
- Agents picking tasks from a board (direction 1).
- Decisions by a master that is a separate headless agent (today the master is your main session).
- Langfuse/OTel export (NDJSON → OTLP is a small converter).
