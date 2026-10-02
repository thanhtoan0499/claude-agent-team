# Delegation brief — what every `Agent` / `SendMessage` brief contains

Agents start with zero context and cannot guess unstated limits. Vague briefs make them duplicate work, leave gaps, or invent
requirements (Anthropic, benzhuk "mandate standards"). The hook logs your brief verbatim as `task_assigned`, so a weak brief is
visible in the log and `team-retro` will find it.

```
OBJECTIVE:      one sentence, the outcome (not the steps)
READ FIRST:     paths, not summaries — .team-log/<feature>/plan.md, the contract section, CLAUDE.md rules that apply, files:lines,
                and the repo's own knowledge for this role if it exists: .claude/agents/<role>.md (e.g. backend-dev, frontend-dev,
                reviewer) and the .claude/rules/*.md files the diff touches. The plugin's role skills carry discipline, the repo carries domain.
TERRITORY:      the files you may edit (disjoint from every other agent running now)
NOT:            everything else — other agents' files, the main checkout, running dev servers/ports, git push/commit, ADO writes,
                new dependencies, drive-by refactors
ACCEPTANCE:     testable bullets (the ticket's AC mapped to this task)
EVIDENCE:       what you must return so I can act without re-checking — file:line for every claim, the exact command + exit code +
                pass/fail counts, "VERDICT: PASS|FAIL|BLOCKED" as line 1 for qa/reviewer
NEGATIVE OK:    "If the premise is wrong, the test cannot fail for the stated reason, or the fix does not work, say so plainly. A red,
                honest result is worth more than a green one that is not real."
AUTONOMY:       decide yourself (reversible, inside TERRITORY, no new contract): <examples>. Return NEEDS_DECISION for: <examples>
BUDGET:         max 8 iterations; same error 3 times -> stop and report what you tried, what failed, what is ruled out
```

Before dispatch, check each step of ACCEPTANCE can be done by the agent (credentials, a browser session, a human-only login).
If not, do it yourself first or take it out of the definition of done — otherwise you get a BLOCKED report.

After the agent returns, do not trust the reply:
1. Read the evidence lines (command, exit code, counts). Missing evidence = unknown, not PASS.
2. Builders: `git diff --name-only` against TERRITORY. A file outside it is a finding, not a footnote.
3. Pass work on by path (plan.md, the agent's report ref), never by retyping a summary.

Resuming an agent (`SendMessage`) uses the same shape, shorter: what changed since the brief, the decision, what to do next.
