#!/usr/bin/env bash
# Runnable self-check: logging rules + hook + report. usage: bash tests/test_log.sh
set -euo pipefail
B=$(cd "$(dirname "$0")/../bin" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
git -C "$T" init -q; cd "$T"
"$B/team-log" feature_start --body "demo" --feature demo
"$B/team-log" task_assigned --to backend --task t1 --body "add endpoint"
! "$B/team-log" decision --body "x" 2>/dev/null || { echo "FAIL: decision without rationale accepted"; exit 1; }
! "$B/team-log" question --body "x" 2>/dev/null || { echo "FAIL: question without --from accepted"; exit 1; }
echo '{"hook_event_name":"SubagentStop","agent_type":"backend","agent_id":"a1","cwd":"'"$T"'","last_assistant_message":"NEEDS_DECISION\nquestion: which id type?\noptions: uuid | int"}' | "$B/team-hook"
echo '{"hook_event_name":"SubagentStop","agent_type":"backend","agent_id":"a1","cwd":"'"$T"'","last_assistant_message":"DONE\nchanged: a.py"}' | "$B/team-hook"
"$B/team-log" decision --from master --to backend --body "uuid" --rationale "matches existing ids"
f=.team-log/demo/events.ndjson
[ "$(wc -l < $f)" = 5 ] || { echo "FAIL: expected 5 events, got $(wc -l < $f)"; exit 1; }
[ "$(jq -s 'map(select(.type=="question"))|length' $f)" = 1 ] || { echo "FAIL: question not logged"; exit 1; }
# worktree path resolves to its own feature slug, shared root log
mkdir -p .claude/worktrees/wt1; ( cd .claude/worktrees/wt1 && "$B/team-log" note --body hi )
[ -s .team-log/wt1/events.ndjson ] || { echo "FAIL: worktree slug"; exit 1; }
"$B/team-report" demo | tail -1
# agent_id lands in log; TUI index pairs start/stop into a duration and keeps Q&A
[ "$(jq -s 'map(select(.agent_id=="a1"))|length' $f)" -ge 2 ] || { echo "FAIL: agent_id not logged"; exit 1; }
"$B/team-tui" --dump | grep -q "demo" || { echo "FAIL: tui feature list"; exit 1; }
out=$("$B/team-tui" --dump demo); grep -q "WHY: matches existing ids" <<<"$out" || { echo "FAIL: tui rationale"; exit 1; }
grep -q "NEEDS_DECISION" <<<"$out" || { echo "FAIL: tui question"; exit 1; }
[ -s .team-log/team.db ] || { echo "FAIL: sqlite index"; exit 1; }
echo PASS
