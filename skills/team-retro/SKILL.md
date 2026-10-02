---
name: team-retro
description: Analyse the team log of one ticket, or of ALL tickets and repos, to find what to improve in the agents — repeated questions, reversed decisions, agents the reviewer keeps catching, escalations, before/after a plugin version. Use after a team-lead run, or on "retro", "nâng cấp team", "xem log team".
---

# Team retro

0. `team-outcome` first: it appends what happened to each logged PR (merged? changes requested? commits after opening = rework).
   A run is judged by its outcome and its cost, not by how quiet it was.
1. `team-report <feature>` for the timeline (omit arg = current feature). Raw file: `<repo>/.team-log/<feature>/events.ndjson`.
2. Compute with jq (all events are one JSON per line):
   - questions per agent: `jq -s 'map(select(.type=="question"))|group_by(.from)|map({a:.[0].from,n:length})' f`
   - decisions with their rationale, to spot patterns the master keeps repeating (= should be in the agent's prompt).
   - review_findings grouped by `.from`/file area (= which builder needs a sharper prompt).
3. Output, max 1 page: (a) repeated questions → rule to add to that agent's `.md`; (b) decisions that were
   reversed → contract/planner gap; (c) concrete diffs to `agents/*.md` or `skills/team-lead/SKILL.md`.
4. Do NOT edit agents without the user's OK.

## Across tickets and repos (the shared index)

Every repo's log is indexed in `~/.claude/agent-team/team.db` (table `events`: src, repo, feature, line, ts, type, frm, dst,
task, body, rationale, options, agent_id, ticket, ttype, title, decided_by, verdict, codes, plugin_version, model, tokens_in, tokens_cache, tokens_out, secs, turns). Query it with
`team-tui --query "<SQL>"` (read-only, tab-separated; works from any directory). Events written before 0.1.13 have no
`plugin_version`. Use this when one ticket is too small a sample to justify a prompt change (3+ tickets showing the same thing).

- Did an upgrade help? `select coalesce(plugin_version,'before 0.1.13') v, count(distinct src||'/'||feature) tickets,
  sum(type='question') questions, sum(type='escalation') escalations, sum(type='gate' and verdict='ESCALATE') gate_escalate,
  sum(type='decision' and decided_by='user') user_decisions from events group by 1 order by 1` — compare per ticket, not totals.
- Same question asked again: `select frm agent, substr(body,1,70) q, count(*) n from events where type='question' group by 1,2 having n>1 order by n desc`
- Where the reviewer keeps finding things: `select repo, feature, count(*) from events where type='review_finding' group by 1,2 order by 3 desc`
- Who decides: `select decided_by, count(*) from events where type='decision' group by 1`
- Cost per agent and model: `select frm agent, model, count(*) runs, sum(tokens_out) out, sum(tokens_in+tokens_cache) input,
  sum(secs)/60 minutes from events where type in ('worker_done','question') and turns is not null group by 1,2 order by input desc`
- Outcome per ticket (quality next to cost): `select o.feature, o.verdict, o.body, (select sum(tokens_in+tokens_cache+tokens_out) from events u
  where u.src=o.src and u.feature=o.feature) tokens from events o where o.type='outcome' and o.line=(select max(line) from events x
  where x.src=o.src and x.feature=o.feature and x.type='outcome')`
- Gate outcomes by reason: `select verdict, codes, count(*) from events where type='gate' group by 1,2`

State the sample size next to every number. A pattern in one ticket is an anecdote, not a rule.
