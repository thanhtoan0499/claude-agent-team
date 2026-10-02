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
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:backend","agent_id":"a1","cwd":"'"$T"'","last_assistant_message":"NEEDS_DECISION\nquestion: which id type?\noptions: uuid | int"}' | "$B/team-hook"
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:backend","agent_id":"a1","cwd":"'"$T"'","last_assistant_message":"DONE\nchanged: a.py"}' | "$B/team-hook"
echo '{"hook_event_name":"SubagentStop","agent_type":"","agent_id":"zz","cwd":"'"$T"'","last_assistant_message":"noise"}' | "$B/team-hook"
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
# in-ticket scrolling: j/k move the log, not the ticket list
python3 - "$B/team-tui" <<'PY'
import importlib.machinery as im, importlib.util as iu, sys
l = im.SourceFileLoader("tt", sys.argv[1]); m = iu.module_from_spec(iu.spec_from_loader("tt", l)); l.exec_module(m)
S, o = m.scroll, ord
assert S(o("j"), 5, False, 10, 17) == (6, False)
assert S(o("j"), 10, True, 10, 17) == (10, True)
assert S(o("k"), 10, True, 10, 17) == (9, False)
assert S(o("k"), 0, False, 10, 17) == (0, False)
assert S(o("g"), 7, False, 10, 17) == (0, False)
assert S(o("G"), 0, False, 10, 17) == (10, True)
assert S(o(" "), 3, False, 10, 17) == (10, True)
assert S(o("b"), 12, False, 20, 17) == (0, False)
assert S(o("j"), 0, False, 0, 17) == (0, True)
PY
# ---- v0.1.4: full reports, handback transcript, tool_call/error, master/user events ----
export TEAM_HOOK_RETRIES=0
"$B/team-log" feature_start --body "v4" --feature v4
f4=.team-log/v4/events.ndjson
# 1. agent ends via SubagentHandback: last_assistant_message is EMPTY, report lives in the subagent transcript
mkdir -p sess/subagents
python3 - <<'PY'
import json
long = "PLAN " + "x" * 5000 + "\nNEEDS_DECISION\nquestion: scope A or B?\noptions: A | B"
rows = [{"type": "assistant", "message": {"content": [{"type": "text", "text": "thinking aloud"}]}},
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "SubagentHandback", "input": {"message": long}}]}}]
open("sess/subagents/agent-h1.jsonl", "w").write("\n".join(json.dumps(r) for r in rows) + "\n")
PY
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:planner","agent_id":"h1","cwd":"'"$T"'","transcript_path":"'"$T"'/sess.jsonl","last_assistant_message":""}' | "$B/team-hook"
[ "$(jq -s 'map(select(.type=="question" and .agent_id=="h1"))|length' $f4)" = 1 ] || { echo "FAIL: handback NEEDS_DECISION not logged as question"; exit 1; }
[ "$(jq -s 'map(select(.type=="question"))|.[0].body|length' $f4)" -gt 5000 ] || { echo "FAIL: question body truncated"; exit 1; }
# 2. explicit agent_transcript_path wins over the derived one
cp sess/subagents/agent-h1.jsonl alt.jsonl
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:qa","agent_id":"h2","cwd":"'"$T"'","agent_transcript_path":"'"$T"'/alt.jsonl","last_assistant_message":""}' | "$B/team-hook"
[ "$(jq -s 'map(select(.agent_id=="h2" and .type=="question"))|length' $f4)" = 1 ] || { echo "FAIL: agent_transcript_path"; exit 1; }
# 3. plain report (no marker) stays worker_done; marker as prose mid-line is NOT a question
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:backend","agent_id":"h3","cwd":"'"$T"'","last_assistant_message":"DONE\nnotes: handled the NEEDS_DECISION path in code"}' | "$B/team-hook"
[ "$(jq -s 'map(select(.agent_id=="h3" and .type=="worker_done"))|length' $f4)" = 1 ] || { echo "FAIL: prose marker misread as question"; exit 1; }
# 4. no transcript, no message -> still a worker_done (never lost)
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:backend","agent_id":"h4","cwd":"'"$T"'"}' | "$B/team-hook"
[ "$(jq -s 'map(select(.agent_id=="h4" and .type=="worker_done"))|length' $f4)" = 1 ] || { echo "FAIL: empty stop dropped"; exit 1; }
# 5. tool calls + errors; handback tool skipped; non-team agent and main thread ignored
echo '{"hook_event_name":"PostToolUse","agent_type":"agent-team:backend","agent_id":"h3","cwd":"'"$T"'","tool_name":"Bash","tool_input":{"command":"uv run pytest -q"}}' | "$B/team-hook"
echo '{"hook_event_name":"PostToolUse","agent_type":"agent-team:backend","agent_id":"h3","cwd":"'"$T"'","tool_name":"SubagentHandback","tool_input":{"message":"x"}}' | "$B/team-hook"
echo '{"hook_event_name":"PostToolUse","agent_type":"Explore","agent_id":"zz","cwd":"'"$T"'","tool_name":"Bash","tool_input":{"command":"ls"}}' | "$B/team-hook"
echo '{"hook_event_name":"PostToolUse","cwd":"'"$T"'","tool_name":"Bash","tool_input":{"command":"ls"}}' | "$B/team-hook"
echo '{"hook_event_name":"PostToolUseFailure","agent_type":"agent-team:backend","agent_id":"h3","cwd":"'"$T"'","tool_name":"Edit","tool_input":{"file_path":"a.py"},"error":"old_string not found"}' | "$B/team-hook"
[ "$(jq -s 'map(select(.type=="tool_call"))|length' $f4)" = 1 ] || { echo "FAIL: tool_call count"; exit 1; }
jq -s -e 'map(select(.type=="tool_call"))[0].body == "Bash: uv run pytest -q"' $f4 >/dev/null || { echo "FAIL: tool_call body"; exit 1; }
jq -s -e 'map(select(.type=="error"))[0].body | test("Edit failed: old_string not found")' $f4 >/dev/null || { echo "FAIL: error event"; exit 1; }
# 6. master/user events
"$B/team-log" escalation --from master --to user --body "scope A/B/C?" --options "A|B|C"
"$B/team-log" user_reply --from user --to master --body "declined / interrupted, no answer given"
"$B/team-log" error --from master --body "AskUserQuestion rejected"
for t in escalation user_reply error; do
  ! "$B/team-log" $t 2>/dev/null || { echo "FAIL: $t without --body accepted"; exit 1; }
done
[ "$(jq -s 'map(select(.type=="escalation" or .type=="user_reply"))|length' $f4)" = 2 ] || { echo "FAIL: escalation/user_reply"; exit 1; }
# 7. report + TUI render the new types
r=$("$B/team-report" v4); grep -q "escalations: 1 | errors: 2" <<<"$r" || { echo "FAIL: report counts"; exit 1; }
d=$("$B/team-tui" --dump v4); grep -q "user_reply" <<<"$d" && grep -q "Bash: uv run pytest" <<<"$d" || { echo "FAIL: tui new types"; exit 1; }
# 8. concurrent writers with bodies >> 4 KB must not corrupt the log
big=$(head -c 30000 /dev/zero | tr '\0' 'x')
"$B/team-log" feature_start --body "conc" --feature conc
for i in $(seq 24); do ( "$B/team-log" worker_done --from agent-team:backend --agent-id c$i --body "$big" ) & done; wait
fc=.team-log/conc/events.ndjson
[ "$(wc -l < $fc)" = 25 ] && [ "$(jq -c . $fc | wc -l)" = 25 ] || { echo "FAIL: concurrent appends corrupted the log"; exit 1; }
# ---- v0.1.5: master/user events captured by hook, CURRENT lifecycle, ms timestamps, ref ----
"$B/team-log" feature_start --body "v5" --feature v5
f5=.team-log/v5/events.ndjson
M() { echo "$1" | "$B/team-hook"; }
M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"cho mình xem plan"}'
M '{"hook_event_name":"PreToolUse","cwd":"'"$T"'","tool_name":"Agent","tool_input":{"subagent_type":"agent-team:planner","description":"plan it","prompt":"Plan the fix for X"}}'
M '{"hook_event_name":"PreToolUse","cwd":"'"$T"'","tool_name":"SendMessage","tool_input":{"to":"planner","message":"decision: A","summary":"s"}}'
M '{"hook_event_name":"PreToolUse","cwd":"'"$T"'","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Scope?","header":"Scope","options":[{"label":"A","description":"actor only"},{"label":"B","description":"all"}]}]}}'
M '{"hook_event_name":"PostToolUse","cwd":"'"$T"'","tool_name":"AskUserQuestion","tool_response":{"answers":{"Scope?":"A"}}}'
M '{"hook_event_name":"PostToolUseFailure","cwd":"'"$T"'","tool_name":"AskUserQuestion","error":"user declined"}'
M '{"hook_event_name":"PostToolUse","cwd":"'"$T"'","tool_name":"Bash","tool_input":{"command":"ls"}}'
t() { jq -s -e "$1" $f5 >/dev/null || { echo "FAIL: $2"; exit 1; }; }
t 'map(select(.type=="user_reply" and .body=="cho mình xem plan" and .from=="user"))|length==1' "UserPromptSubmit -> user_reply"
t 'map(select(.type=="task_assigned" and .to=="agent-team:planner" and .task=="plan it" and .body=="Plan the fix for X"))|length==1' "Agent -> task_assigned"
t 'map(select(.type=="task_assigned" and .to=="planner" and .body=="decision: A"))|length==1' "SendMessage -> task_assigned"
t 'map(select(.type=="escalation" and (.body|test("Scope")) and (.body|test("actor only")) and .options==["A","B"]))|length==1' "AskUserQuestion -> escalation"
t 'map(select(.type=="user_reply" and (.body|test("\"A\""))))|length==1' "AskUserQuestion answer -> user_reply"
t 'map(select(.type=="error" and (.body|test("AskUserQuestion failed: user declined"))))|length==1' "AskUserQuestion failure -> error"
t 'map(select(.body=="Bash: ls"))|length==0' "main-thread Bash must not be logged"
# no active feature -> main thread is NOT captured; stale CURRENT (>12h) too
"$B/team-log" feature_end --feature v5
[ ! -e .team-log/CURRENT ] || { echo "FAIL: feature_end did not clear CURRENT"; exit 1; }
n=$(wc -l < $f5)
M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"unrelated chat"}'
[ "$(wc -l < $f5)" = "$n" ] || { echo "FAIL: logged a prompt with no active feature"; exit 1; }
echo v5 > .team-log/CURRENT; touch -d '13 hours ago' .team-log/CURRENT
M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"stale"}'
[ "$(wc -l < $f5)" = "$n" ] || { echo "FAIL: stale CURRENT still captured"; exit 1; }
rm -f .team-log/CURRENT
# activity keeps CURRENT fresh
"$B/team-log" feature_start --body "v5b" --feature v5; touch -d '11 hours ago' .team-log/CURRENT
"$B/team-log" note --body ping
[ -n "$(find .team-log/CURRENT -mmin -5)" ] || { echo "FAIL: event did not refresh CURRENT"; exit 1; }
# subagent start carries ref to its transcript; timestamps carry ms (GNU date) and TUI still parses them
M '{"hook_event_name":"SubagentStart","agent_type":"agent-team:qa","agent_id":"r1","cwd":"'"$T"'","transcript_path":"'"$T"'/s.jsonl"}'
t 'map(select(.type=="agent_started" and .agent_id=="r1" and (.ref|test("s/subagents/agent-r1.jsonl$"))))|length==1' "agent_started ref"
"$B/team-tui" --dump v5 >/dev/null || { echo "FAIL: tui cannot parse ms timestamps"; exit 1; }
# ---- v0.1.6: ticket-first naming, hook+agent ticket logging ----
rm -f .team-log/CURRENT
# slug = <type>-<ticket>-<title-slug>, diacritics folded; --ticket without title -> wi-<n>
"$B/team-log" feature_start --ticket 8991 --type bug --title "[FE][Serving] Activate version mới ghi đè admin layout" --body "req"
[ "$(head -1 .team-log/CURRENT)" = "bug-8991-fe-serving-activate-version-moi-ghi-de-admin-layout" ] || { echo "FAIL: slug: $(cat .team-log/CURRENT)"; exit 1; }
"$B/team-log" feature_start --ticket 7001 --body "req"
[ "$(head -1 .team-log/CURRENT)" = "wi-7001" ] || { echo "FAIL: wi slug"; exit 1; }
# same ticket again (agent after hook) REUSES the feature, enriches it, no second directory
"$B/team-log" feature_start --ticket 7001 --type task --title "Fix export" --body "req"
[ "$(ls -d .team-log/*-7001* | wc -l)" = 1 ] || { echo "FAIL: duplicate feature for one ticket"; exit 1; }
jq -s -e 'map(select(.type=="ticket_info" and .ticket=="7001" and .ticket_type=="task" and .title=="Fix export"))|length==1' .team-log/wi-7001/events.ndjson >/dev/null || { echo "FAIL: reuse -> ticket_info"; exit 1; }
! "$B/team-log" ticket_info --ticket 9999 --title x 2>/dev/null || { echo "FAIL: ticket_info for unknown ticket accepted"; exit 1; }
! "$B/team-log" feature_start --ticket abc 2>/dev/null || { echo "FAIL: non-numeric ticket accepted"; exit 1; }
# TUI: number first
d=$("$B/team-tui" --dump); grep -q "^. \[bug-8991\] \[FE\]\[Serving\] Activate version mới" <<<"$d" || { echo "FAIL: tui label (ticket metadata): $d"; exit 1; }
grep -q "^. \[7001\] Fix export\|^. \[task-7001\] Fix export" <<<"$d" || { echo "FAIL: tui label (reused): $d"; exit 1; }
# older logs without metadata: number read from the slug (type-N-name, name-N)
mkdir -p .team-log/bug-5555-old-style .team-log/widget-thing-6666 .team-log/plain
for f in bug-5555-old-style widget-thing-6666 plain; do "$B/team-log" note --feature $f --body x; done
d=$("$B/team-tui" --dump)
grep -q "\[bug-5555\] old style" <<<"$d" && grep -q "\[6666\] widget thing" <<<"$d" && grep -q "^.  *plain" <<<"$d" || { echo "FAIL: tui slug fallback: $d"; exit 1; }
# hook: `/agent-team:team-lead <url>` opens the feature at once; az (fake) fills type+title in the background
rm -f .team-log/CURRENT; mkdir -p fakebin
cat > fakebin/az <<'AZ'
#!/usr/bin/env bash
echo '{"fields":{"System.WorkItemType":"Bug","System.Title":"Hook fetched title"}}'
AZ
chmod +x fakebin/az
PATH="$T/fakebin:$PATH" M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"/agent-team:team-lead https://dev.azure.com/acme/Proj/_workitems/edit/8123"}'
[ "$(head -1 .team-log/CURRENT)" = "wi-8123" ] || { echo "FAIL: hook did not open wi-8123"; exit 1; }
for i in $(seq 30); do jq -s -e 'map(select(.type=="ticket_info"))|length>=1' .team-log/wi-8123/events.ndjson >/dev/null 2>&1 && break; sleep 0.2; done
jq -s -e 'map(select(.type=="ticket_info" and .ticket_type=="bug" and .title=="Hook fetched title"))|length==1' .team-log/wi-8123/events.ndjson >/dev/null || { echo "FAIL: background team-ticket did not log ticket_info"; exit 1; }
jq -s -e 'map(select(.type=="user_reply"))|length>=1' .team-log/wi-8123/events.ndjson >/dev/null || { echo "FAIL: the prompt itself not logged"; exit 1; }
"$B/team-tui" --dump | grep -q "\[bug-8123\] Hook fetched title" || { echo "FAIL: tui label after hook"; exit 1; }
# repeating the prompt while that feature is active does not start another; a prompt without team-lead never starts one
n=$(ls .team-log | wc -l)
PATH="$T/fakebin:$PATH" M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"/agent-team:team-lead AB#8123 again"}'
M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"look at https://dev.azure.com/acme/Proj/_workitems/edit/4242"}'
[ "$(ls .team-log | wc -l)" = "$n" ] || { echo "FAIL: spurious feature started"; exit 1; }
# a different ticket while another feature is active DOES start its own feature
PATH="$T/fakebin:$PATH" M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"/agent-team:team-lead AB#8124"}'
[ "$(head -1 .team-log/CURRENT)" = "wi-8124" ] || { echo "FAIL: second ticket did not switch feature"; exit 1; }
# team-ticket is silent without az
PATH=/usr/bin:/bin "$B/team-ticket" 8124 >/dev/null 2>&1; true
unset TEAM_HOOK_RETRIES
echo PASS
