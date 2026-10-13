# Delegation brief — what every `Agent` / `SendMessage` brief contains

Agents start with zero context and cannot guess unstated limits. Vague briefs make them duplicate work, leave gaps, or invent
requirements (Anthropic, benzhuk "mandate standards"). The hook logs your brief verbatim as `task_assigned`, so a weak brief is
visible in the log and `team-retro` will find it.

```
OBJECTIVE:      one sentence, the outcome (not the steps)
READ FIRST:     paths, not summaries — .team-log/<feature>/plan.md, the contract section, CLAUDE.md rules that apply, files:lines,
                and the repo's own knowledge for this role if it exists: .claude/agents/<role>.md (e.g. backend-dev, frontend-dev,
                reviewer) and the .claude/rules/*.md files the diff touches. The plugin's role skills carry discipline, the repo carries domain.
CODE NAV:       if the repo has `.codegraph/`: "your first code lookup is codegraph_explore, projectPath=<worktree or repo root>";
                name the symbols/files to start from. grep/find only for plain strings and non-code files.
TERRITORY:      the files you may edit (disjoint from every other agent running now)
NOT:            everything else — other agents' files, the main checkout, running dev servers/ports, git push/commit, ADO writes,
                new dependencies, drive-by refactors
ACCEPTANCE:     testable bullets (the ticket's AC mapped to this task)
EVIDENCE:       what you must return so I can act without re-checking — file:line for every claim, the exact command + exit code +
                pass/fail counts, "VERDICT: PASS|FAIL|BLOCKED" as line 1 for qa/reviewer
NEGATIVE OK:    "If the premise is wrong, the test cannot fail for the stated reason, or the fix does not work, say so plainly. A red,
                honest result is worth more than a green one that is not real."
AUTONOMY:       decide yourself (reversible, inside TERRITORY, no new contract): <examples>. Return NEEDS_DECISION for: <examples>
RUN:            workers = <team-cores output> for pytest -n / vitest --maxWorkers / playwright --workers; one command per Bash
                call (`uv run --directory d ...`, `pnpm --dir d ...`, not `cd d && ...`); stop a server by port (`fuser -k 5199/tcp`),
                never `pkill -f "<its own command line>"` (it matches and kills your own shell: exit 144). Builders: only the tests for
                the changed files + the ones named here, quiet (`-q --tb=short`); full suite = qa. No docker rebuild unless asked.
BASELINE:       <abs path>/.team-log/<feature>/baseline.md — red checks listed there are not yours; tag every red check NEW|BASELINE
BUDGET:         max 8 iterations; same error 3 times -> stop and report what you tried, what failed, what is ruled out.
                ~60 tool calls per run (a hook reminds you once): near it, finish the current step and report DONE with
                `remaining:` instead of pushing on in an ever longer context
```

Before dispatch, check each step of ACCEPTANCE can be done by the agent (credentials, a browser session, a human-only login).
If not, do it yourself first or take it out of the definition of done — otherwise you get a BLOCKED report.

After the agent returns, do not trust the reply:
1. Read the evidence lines (command, exit code, counts). Missing evidence = unknown, not PASS.
2. Builders: `git diff --name-only` against TERRITORY. A file outside it is a finding, not a footnote.
3. Pass work on by path (plan.md, the agent's report ref), never by retyping a summary.

Resuming an agent (`SendMessage`) uses the same shape, shorter: what changed since the brief, the decision, what to do next.

## FIX brief — a fix round as a fresh run
Resume (`SendMessage`) only an agent whose last run was short (≤ 40 tool uses, shown in the Agent result) or that is waiting on
your decision: a resumed long run drags its whole 150–200k context into every turn of the fix. Otherwise dispatch a fresh run:

```
OBJECTIVE:      fix <finding ids> in <task id>
FINDINGS:       one line each: severity | file:line | what is wrong | expected (verbatim from the reviewer/qa report)
READ FIRST:     the finding files:lines, plan.md contract section, the previous report ref — nothing to rediscover
TRIED BEFORE:   what the last round changed and why it did not hold (R1 reflection, escalation-ladder.md)
TERRITORY/NOT/EVIDENCE/RUN/BUDGET: as above; the tests to run = the ones that failed + the files touched
```
