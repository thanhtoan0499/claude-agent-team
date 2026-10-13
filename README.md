# agent-team

A Claude Code plugin that builds one feature with a team of AI agents and logs every step.

## What it does
- Your Claude session becomes the **master**: it splits the feature into tasks and hands them to agents:
  `planner` → `designer` → `backend` ∥ `frontend` → `qa` → `reviewer`.
- Agents don't guess. When stuck they ask the master (`NEEDS_DECISION`); the master decides with a reason
  and only asks **you** once per phase (plan approval + questions that really need you).
- Tests run before and after the change; the repo's verify suite must pass before a PR is opened.
- Every task, question, decision and agent report is logged to `.team-log/<ticket>/events.ndjson`,
  so you can see who did what and why, and what it cost (time, tokens).

## Install
```
/plugin marketplace add thanhtoan0499/claude-agent-team
/plugin install agent-team@agent-team-marketplace
```
Requires `jq` and `git`. Optional: the `codegraph` MCP server (faster code lookup),
[`parallel-worktree-run`](https://github.com/thanhtoan0499/claude-parallel-worktree-plugin) (a live stack per branch).

## Use
In Claude Code, inside your repo:
```
/agent-team:team-lead <ticket URL | AB#1234 | feature description>
```
or just say "dùng team làm feature X". Approve the plan when asked, answer the few questions, then choose
`Commit + push + draft PR` / `Commit only` / `Stop` at the end.

See what happened (scripts in the plugin's `bin/`, put it on PATH):
```
team-tui                  # all tickets across repos; Enter = timeline, q = quit
team-report [feature]     # text timeline: questions, decisions and why
/agent-team:team-retro    # in Claude Code: analyse logs to improve the agents
```

Details (log format, hooks, models, guards, TUI keys): [docs/reference.md](docs/reference.md).
