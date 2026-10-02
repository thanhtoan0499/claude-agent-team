---
name: team-retro
description: Analyse a feature's team log (.team-log/<feature>/events.ndjson) to find what to improve in the agents — repeated questions, reversed decisions, agents the reviewer keeps catching, escalations. Use after a team-lead run, or when the user says "retro", "nâng cấp team", "xem log team".
---

# Team retro

1. `team-report <feature>` for the timeline (omit arg = current feature). Raw file: `<repo>/.team-log/<feature>/events.ndjson`.
2. Compute with jq (all events are one JSON per line):
   - questions per agent: `jq -s 'map(select(.type=="question"))|group_by(.from)|map({a:.[0].from,n:length})' f`
   - decisions with their rationale, to spot patterns the master keeps repeating (= should be in the agent's prompt).
   - review_findings grouped by `.from`/file area (= which builder needs a sharper prompt).
3. Output, max 1 page: (a) repeated questions → rule to add to that agent's `.md`; (b) decisions that were
   reversed → contract/planner gap; (c) concrete diffs to `agents/*.md` or `skills/team-lead/SKILL.md`.
4. Do NOT edit agents without the user's OK.
