# Escalation ladder — failures, stuck agents, dead agents

Fix loops (qa/reviewer finding, failing test) escalate in rounds. Keep the round number in your `note`s.

| round | action |
|---|---|
| R1 | Send the finding back to the owning builder (`SendMessage`). The message must say: what failed, what you changed last time, what to do differently. A retry without that reflection repeats the mistake. |
| R2 | Same or related failure again. Write a handoff note (what was tried, why it failed, what is ruled out). Dispatch `agent-team:qa` on `model: "opus"` to **diagnose, not fix**: reproduce, root cause, evidence. The builder then fixes from the diagnosis, by path. |
| R3 | Stop. ONE `AskUserQuestion`: take over / new direction / abandon, with links to the handoff note and diagnosis. |

Stuck: any agent that hits the same error 3 times, or its 8-iteration budget, stops and reports (it is in every brief). You do not
nudge a stuck agent a 4th time; you go up the ladder.

Dead or interrupted agent (API error, session cut): resume the SAME agent first with `SendMessage`: "you were interrupted; run
`git diff` on your territory, sort the work into done / partial / untouched, finish the rest". Respawn only if that fails.

Done means evidence. A phase is closed only when the report carries the command, exit code and pass/fail counts. Never mark
qa or review done on a verdict word alone.

Decision rounds (agent asks, you answer) are separate: max 2 per agent per task, enforced by `team-gate --to <agent> --task <id>`.
