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

## Baseline, verify, PR (v0.1.15)
- **Baseline before the first edit.** `qa` runs the repo's verify suite + the tests the plan names on the untouched base and writes
  `.team-log/<feature>/baseline.md`; the master logs `baseline --verdict CLEAN|RED`. A check already red on the base is **not** the
  ticket's failure: qa/reviewer tag every red check `NEW` or `BASELINE`, only `NEW` enters the fix loop. A red base is fixed as a
  separate `B<n>` task when it is reversible, local and not security (one round, `decided_by policy`), and reported once at the end.
- **Verify before PR.** The repo's verify suite (`.claude/skills/verify/SKILL.md`, `.claude/commands/verify.md`, or a Makefile/CLAUDE.md
  target) must pass before the end question; then the repo's PR rules (e.g. `pr-doc`). ONE `AskUserQuestion` carries the end report
  (incl. Baseline) and `Commit + push + draft PR` / `Commit only` / `Stop`.
- **`bin/team-cores`** prints the worker count for parallel runners now: `nproc - ceil(1-min load)`, min 2, max nproc. Briefs pass it to
  pytest `-n`, vitest `--maxWorkers`, playwright `--workers` instead of `auto`, which ignores other load on the box.
  Rules: `skills/team-lead/references/baseline-and-verify.md`.

## Models (v0.1.16)
Each agent file pins its model: `planner`, `reviewer` = **opus** (a wrong contract or a weak review costs the whole run);
`backend`, `frontend`, `qa`, `designer` = **sonnet** (bounded work on a frozen contract). The master is your session (`/model`, Opus).
The master may only raise a model per dispatch (size L, R2 diagnosis, re-dispatch after a failed R1), never lower one
(`skills/team-lead/references/triage.md`). The hook stamps the model on every `task_assigned`; `team.db` has a `model` column so
`team-retro` can compare outcomes per model. `tests/test_skills.sh` fails if an agent's `model:` drifts from that table.

## Logging for optimisation (v0.1.17)
- **Only the team's session is logged.** The session that opens the feature (`/agent-team:team-lead <ticket>` or `team-log feature_start`)
  is bound in `.team-log/sessions/<session id>` (since 0.1.24; before, one `CURRENT.session` per repo); prompts from another Claude
  Code session in the same repo never reach the ticket's log. A new session on the same ticket re-runs `feature_start` (or
  `/agent-team:team-lead <ticket>`) to take over.
- **Every event goes to its session's ticket** (0.1.24): two sessions running two tickets in one repo at once each log into their
  own ticket, their subagents' events included (the hook routes by the payload's `session_id`, a `team-log` run from Bash by
  `CLAUDE_CODE_SESSION_ID`). Without a session: a worktree named after a ticket (`serving-8810`) logs into the feature tracking
  that ticket, else the active feature (`CURRENT`), never a slug per worktree name while one is active.
- **Time and tokens in `team-tui`** (0.1.24): the list shows *active* time (gaps between events capped at 15 min, 2 h while an agent
  runs: nights and waits for you do not count); the ticket footer shows active time, the first-to-last span and agent time
  (agent_started -> its report, per run). Tokens count each agent once at its largest report: a resumed agent's transcript
  repeats its earlier runs. A ticket whose agents never reported back stops showing ● after 2 h of silence.
- **Cost per agent run.** `worker_done`/`question` carry the model it really ran on and `tokens_in`, `tokens_cache`, `tokens_out`,
  `secs`, `turns`, read from the subagent transcript; `team.db` has the same columns, `team-tui` shows model + tokens per report.
- **The PR closes the log.** `gh pr create` by the master -> `pr` (URL) + `feature_end`, by the hook.
- **Outcome.** `bin/team-outcome` asks GitHub what happened to every logged PR (state, reviews, changes requested, comments,
  commits pushed after opening = rework, size, days) and appends an `outcome` event when it changed. `team-retro` runs it first.

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
`<repo>/.team-log/<feature>/events.ndjson`, one JSON per line. Worktrees share the main repo's log; with no session
binding, no ticket number in the worktree name and no active feature, the worktree name is the feature slug.

| type | written by |
|---|---|
| `pr` (PR URL) + `feature_end` | hook, on the master's `gh pr create` |
| `outcome` (`MERGED`/`OPEN`/`DRAFT`/`CLOSED` + counts) | `bin/team-outcome` |
| `feature_start`, `feature_end`, `ticket_info`, `decision` (+`decided_by`), `review_finding`, `stack_provisioned`, `note` | master via `team-log` |
| `gate` (verdict + codes for one open question) | `team-gate` |
| `agent_started`, `worker_done`, `question` | `SubagentStart/Stop` hook. Body = the agent's FULL final report (read from the subagent transcript when the agent ends via `SubagentHandback`); a `NEEDS_DECISION` line makes it a `question`; `ref` = path of the agent's transcript |
| `tool_call`, `error` | `PostToolUse` / `PostToolUseFailure` hook for agent-team agents (one line per call) |
| `task_assigned` (master's brief), `escalation` (question to the user), `user_reply` (user prompt / answer), `error` (failed Agent/SendMessage/AskUserQuestion) | main-thread hooks (`PreToolUse` Agent/SendMessage/AskUserQuestion, `UserPromptSubmit`, `PostToolUse(Failure)`), **only while a feature is active, from the session bound to it**: `.team-log/CURRENT` set by `feature_start`, refreshed by every event, expires after 12 h idle, cleared by `feature_end`; `.team-log/sessions/<id>` = the feature each session runs |

Appends are serialised with `flock` (parallel agents with large bodies would otherwise interleave lines). Timestamps carry milliseconds where GNU `date` supports it.

`TEAM_HOOK_DEBUG=/tmp/hook.ndjson` appends every raw hook payload to that file, for diagnosing a missing event.

```
bin/team-tui                  # lazygit-style, ALL repos at once: left = tickets (with repo), Enter = timeline (agents, questions, decisions+WHY)
bin/team-report [feature]     # timeline: who asked what, what master decided and WHY
/agent-team:team-retro        # find repeated questions / reversed decisions → improve agent prompts
bash tests/test_log.sh        # self-check
```
**Shared index.** Hooks still append to `<repo>/.team-log/<ticket>/events.ndjson` (the source of truth). `team-log` also lists the repo in
`~/.claude/agent-team/repos`, and `team-tui` keeps a derived SQLite index of all of them in `~/.claude/agent-team/team.db`, so you can open it
from any directory and see every repo's tickets. The repo you run it in is added automatically; `team-tui --add <repo>` adds one by hand.
`team-tui --query "<SQL>"` runs read-only SQL over it (`team-retro` uses this to compare tickets and plugin versions; every event carries
`plugin_version`). Delete `team.db` any time: it is rebuilt from the NDJSON files. `TEAM_HOME` moves the folder; `TEAM_LOG_DIR=<dir>` restricts
the TUI to one log folder with its own `team.db` inside. Logs hold ticket text, agent reports and the commands run, so this folder collects
every project's in one place under your home.

`team-tui` keys: j/k move (list) or scroll (inside a ticket) · g/G (or Home/End) first/last ticket, top/end of a log · space/b page · o expand the collapsed body on screen, O expand all · n/p next/prev ticket · c copy the full timeline (wl-copy, xclip, else OSC52) · f Q&A-only · t show/hide tool calls (hidden by default) · r resume the ticket's Claude Code session (`claude --resume`, in the folder it ran in; refused while the ticket is running, R forces; needs a ticket run since 0.1.23, the hook records `session` + `cwd` on the master's and the user's events) · enter open · esc back · q quit. The footer shows `from-to/total TOP|END`. Bodies longer than 20 lines are collapsed to a preview (`… +N more lines`), so a long planner report no longer costs a re-wrap on every key; `--dump` and `c` always give the whole text.
NDJSON is the source of truth; `.team-log/team.db` (SQLite) is a derived index rebuilt incrementally, safe to delete.

`team-log` refuses a `decision` without `--rationale`, a `question` without `--from`, a `task_assigned` without `--to`/`--body`.

## Not yet (v0.1)
- Agents picking tasks from a board (direction 1).
- Decisions by a master that is a separate headless agent (today the master is your main session).
- Langfuse/OTel export (NDJSON → OTLP is a small converter).
