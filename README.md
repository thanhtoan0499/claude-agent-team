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

## The master decides (v0.1.7)
The master is built to decide, not to ask. You are asked **once per phase**: one `AskUserQuestion` = plan approval + only the
questions that truly need you (recommended option first).
- **`bin/team-gate`** — the master states five facts per open question (in-ticket, reversible, external, security, needs-human);
  the script returns `DECIDE` / `ASSUME` / `ESCALATE` + reason codes and logs a `gate` event. The policy is code, not mood
  (pattern from coscc). A 3rd decision round for one agent+task is refused (`ROUND_LIMIT`).
- **`decided_by`** on every `decision` (`master` / `user` / `policy`): "accepted" by an agent is never shown as your approval.
- **Policy card** — the hook re-injects a ~270-token reminder of the policy as context on `SessionStart` (incl. after a compaction)
  and every 6th prompt of the active feature, so the rules do not live only in the first message (pattern from claude-delegation).
- **`plan.md`** — the planner's report is saved to `.team-log/<feature>/plan.md` by the hook; after a compaction the master re-reads the file.
- **Triage S/M/L**, a standard **delegation brief**, and an **escalation ladder** (R1 builder → R2 diagnosis → R3 ask you) live in
  `skills/team-lead/references/`. The planner now returns `OPEN_QUESTIONS` (each with `blocking`, recommendation, default) and `ASSUMPTIONS`.
- `team-report` ends with the gate verdict counts and decisions by decider, so `team-retro` can measure how often the user was needed.

## Naming: ticket number first
A feature that tracks a ticket is named `<type>-<ticket>-<title-slug>` (e.g. `bug-8991-fe-serving-activate-version-moi-ghi-de-admin-layout`)
and `team-tui` shows it as `[bug-8991] <title>`, so tickets are easy to scan and pick. Older logs without metadata are labelled from the
number in their slug (`[8991] name`). `team-log feature_start --ticket N [--type T] [--title X]` builds the name and reuses the feature that
already tracks ticket N.

**Hook + agent in parallel:** typing `/agent-team:team-lead <ADO URL | AB#n>` makes the hook open the feature immediately (exact id, no LLM
involved) and spawn `bin/team-ticket`, which fetches the type and title from Azure DevOps (`az boards`, ~2 s, detached so the prompt is never
delayed; org from the URL or `TEAM_ADO_ORG`). Meanwhile the master reads the ticket and logs the same metadata (`ticket_info`); the TUI shows
the latest. If `az` is missing or not logged in, the master's entry is the only source.

## Role skills (v0.1.8+)
Agents get role discipline from small skills preloaded through the agent's `skills:` frontmatter (full text injected at start, so each is
kept short: <= 100 lines per skill, <= 340 per agent; `bash tests/test_skills.sh` enforces it). Repo-specific knowledge is NOT copied in:
the master points agents at the repo's own files (CLAUDE.md, `.claude/rules/`, `.claude/agents/<role>.md`) in the brief.
| agent | preloaded skills |
|---|---|
| planner | `plan-writing`, `plan-completeness` |
| designer | `ux-spec-format`, `copy-and-restraint`, `a11y-acceptance` |
| backend | `evidence-before-claims`, `tdd-red-green`, `root-cause-first`, `receiving-findings` |
| frontend | the backend four + `react-vite-perf`, `ui-guidelines` |
| qa | `evidence-before-claims`, `tdd-red-green`, `root-cause-first`, `test-quality`, `test-gap-analysis`, `ui-recon-and-a11y-verify` |
| reviewer | `evidence-before-claims`, `review-method`, `silent-failure-and-boundaries`, `stack-checks` |

Reviewer/qa severity is two levels only: `blocker` (fails the verdict) and `major`; style remarks are dropped.
Adapted third-party material and licences: `THIRD_PARTY.md`. A wrong skill name in `skills:` is skipped silently by Claude Code, so after
changing wiring run `bash tests/smoke_preload.sh` (manual, costs a few cents) to see which skills the agent really received.

## Log
`<repo>/.team-log/<feature>/events.ndjson`, one JSON per line. Worktrees share the main repo's log; the
worktree name is the feature slug.

| type | written by |
|---|---|
| `feature_start`, `feature_end`, `ticket_info`, `decision` (+`decided_by`), `review_finding`, `stack_provisioned`, `note` | master via `team-log` |
| `gate` (verdict + codes for one open question) | `team-gate` |
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
