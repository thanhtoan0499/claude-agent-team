#!/usr/bin/env bash
# Runnable self-check: logging rules + hook + report. usage: bash tests/test_log.sh
set -euo pipefail
B=$(cd "$(dirname "$0")/../bin" && pwd)
T=$(mktemp -d); export TEAM_HOME=$(mktemp -d); trap 'rm -rf "$T" "$TEAM_HOME"' EXIT   # never touch the real ~/.claude/agent-team
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
# worktree of the ACTIVE feature logs into that feature (not a slug per worktree), shared root log
mkdir -p .claude/worktrees/wt1; ( cd .claude/worktrees/wt1 && "$B/team-log" note --body "from wt" )
[ ! -e .team-log/wt1 ] && grep -q '"from wt"' $f || { echo "FAIL: worktree event left the active feature"; exit 1; }
sed -i '$d' $f   # keep the event counts below as they were
"$B/team-report" demo | tail -1
# agent_id lands in log; TUI index pairs start/stop into a duration and keeps Q&A
[ "$(jq -s 'map(select(.agent_id=="a1"))|length' $f)" -ge 2 ] || { echo "FAIL: agent_id not logged"; exit 1; }
"$B/team-tui" --dump | grep -q "demo" || { echo "FAIL: tui feature list"; exit 1; }
out=$("$B/team-tui" --dump demo); grep -q "WHY: matches existing ids" <<<"$out" || { echo "FAIL: tui rationale"; exit 1; }
grep -q "NEEDS_DECISION" <<<"$out" || { echo "FAIL: tui question"; exit 1; }
[ -s "$TEAM_HOME/team.db" ] || { echo "FAIL: shared sqlite index"; exit 1; }
[ ! -e .team-log/team.db ] || { echo "FAIL: per-repo team.db should no longer be written"; exit 1; }
# shared index: the repo is registered by team-log, events carry the plugin version, a missing/unwritable home never breaks logging
grep -qxF "$T/.team-log" "$TEAM_HOME/repos" || { echo "FAIL: repo not registered: $(cat "$TEAM_HOME/repos")"; exit 1; }
[ "$(grep -c . "$TEAM_HOME/repos")" = 1 ] || { echo "FAIL: repo registered more than once"; exit 1; }
ver=$(jq -r .version "$B/../.claude-plugin/plugin.json")
jq -e --arg v "$ver" 'select(.plugin_version != $v)' .team-log/demo/events.ndjson >/dev/null && { echo "FAIL: event without plugin_version $ver"; exit 1; }
"$B/team-tui" --query "select plugin_version, count(*) from events where feature='demo' group by 1" | grep -q "^$ver" || { echo "FAIL: plugin_version not in the index"; exit 1; }
TEAM_HOME=/proc/nope/x "$B/team-log" note --body "home unwritable" --feature demo || { echo "FAIL: logging must survive an unwritable TEAM_HOME"; exit 1; }
grep -q "home unwritable" .team-log/demo/events.ndjson || { echo "FAIL: event lost when TEAM_HOME unwritable"; exit 1; }
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
python3 "$B/../tests/test_tui.py" >/dev/null || { python3 "$B/../tests/test_tui.py"; exit 1; }  # keys, lazy bodies, cache, incremental sync
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
M() { echo "$1" | "$B/team-hook" >/dev/null; }     # quiet
MO() { echo "$1" | "$B/team-hook"; }                 # keeps the hook's stdout (policy card JSON)
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
t 'map(select(.type=="task_assigned" and .to=="agent-team:planner" and .model=="opus"))|length==1' "task_assigned carries the agent file's model"
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
d=$("$B/team-tui" --dump); grep -q "^.. \[bug-8991\] \[FE\]\[Serving\] Activate version mới" <<<"$d" || { echo "FAIL: tui label (ticket metadata): $d"; exit 1; }
grep -q "^.. \[7001\] Fix export\|^.. \[task-7001\] Fix export" <<<"$d" || { echo "FAIL: tui label (reused): $d"; exit 1; }
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
# the master's/user's events carry the session + folder (team-tui resumes it); a subagent's events do not
M '{"hook_event_name":"UserPromptSubmit","session_id":"sess-xyz","cwd":"'"$T"'","prompt":"with a session"}'
M '{"hook_event_name":"SubagentStart","session_id":"sess-xyz","cwd":"'"$T"'","agent_type":"agent-team:backend","agent_id":"ses1"}'
jq -s -e 'map(select(.type=="user_reply" and .session=="sess-xyz" and .cwd=="'"$T"'"))|length==1' .team-log/wi-8123/events.ndjson >/dev/null || { echo "FAIL: user_reply lacks session/cwd"; exit 1; }
jq -s -e 'map(select(.type=="agent_started" and .agent_id=="ses1" and (has("session")|not)))|length==1' .team-log/wi-8123/events.ndjson >/dev/null || { echo "FAIL: subagent event carries a session"; exit 1; }
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
# ---- v0.1.7: team-gate, decided_by, policy card, plan.md ----
"$B/team-log" feature_start --feature g7 --body "gate tests"; f7=.team-log/g7/events.ndjson
G() { "$B/team-gate" --no-log "$@"; }   # prints verdict line + next:, rc = 0 decide/assume, 1 escalate
base=(--topic q --in-ticket y --reversible y --external n --security n --needs-human n)
v() { G "$@" 2>/dev/null | head -1; }
[ "$(v "${base[@]}")" = "DECIDE" ] || { echo "FAIL: gate plain DECIDE"; exit 1; }
[ "$(v --topic q --in-ticket n --reversible y --external n --security n --needs-human n)" = "ESCALATE OUT_OF_SCOPE" ] || { echo "FAIL: gate OUT_OF_SCOPE"; exit 1; }
[ "$(v --topic q --in-ticket y --reversible n --external y --security y --needs-human n)" = "ESCALATE IRREVERSIBLE,EXTERNAL_EFFECT,SECURITY" ] || { echo "FAIL: gate multi codes"; exit 1; }
[ "$(v --topic q --in-ticket y --reversible y --external n --security n --needs-human y)" = "ESCALATE NEEDS_HUMAN_INFO" ] || { echo "FAIL: gate needs-human"; exit 1; }
[ "$(v --topic q --in-ticket y --reversible y --external n --security n --needs-human y --placeholder y)" = "ASSUME ASSUMED_PLACEHOLDER" ] || { echo "FAIL: gate placeholder -> ASSUME"; exit 1; }
# a placeholder never rescues an out-of-scope / irreversible question
[ "$(v --topic q --in-ticket n --reversible y --external n --security n --needs-human y --placeholder y)" = "ESCALATE OUT_OF_SCOPE,ASSUMED_PLACEHOLDER" ] || { echo "FAIL: placeholder must not rescue"; exit 1; }
G "${base[@]}" >/dev/null; [ $? = 0 ] || { echo "FAIL: rc decide"; exit 1; }
rc=0; G --topic q --in-ticket n --reversible y --external n --security n --needs-human n >/dev/null || rc=$?; [ "$rc" = 1 ] || { echo "FAIL: rc escalate=$rc"; exit 1; }
rc=0; G --topic q --in-ticket y >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || { echo "FAIL: missing facts must be misuse (rc=$rc)"; exit 1; }
rc=0; G "${base[@]}" --bogus x >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || { echo "FAIL: unknown flag rc=$rc"; exit 1; }
rc=0; G "${base[@]/in-ticket/in-tickt}" >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || { echo "FAIL: typo flag rc=$rc"; exit 1; }
# logging: gate event written; --no-log writes nothing
n=$(wc -l < $f7); G "${base[@]}" >/dev/null; [ "$(wc -l < $f7)" = "$n" ] || { echo "FAIL: --no-log wrote"; exit 1; }
"$B/team-gate" --topic "scope A vs B" --in-ticket y --reversible y --external n --security n --needs-human n --to planner >/dev/null
jq -s -e 'map(select(.type=="gate" and .verdict=="DECIDE" and .body=="scope A vs B" and .from=="master" and .to=="planner"))|length==1' $f7 >/dev/null || { echo "FAIL: gate event not logged"; exit 1; }
# decision default decided_by=master, explicit user/policy kept, junk refused, only valid on decision
"$B/team-log" decision --from master --to planner --task t1 --body "A" --rationale "r1"
"$B/team-log" decision --from master --to planner --task t1 --decided-by user --body "B" --rationale "r2"
jq -s -e '[.[]|select(.type=="decision")|.decided_by]==["master","user"]' $f7 >/dev/null || { echo "FAIL: decided_by values"; exit 1; }
! "$B/team-log" decision --body x --rationale y --decided-by robot 2>/dev/null || { echo "FAIL: bad decided_by accepted"; exit 1; }
! "$B/team-log" note --body x --decided-by user 2>/dev/null || { echo "FAIL: decided_by on a note accepted"; exit 1; }
! "$B/team-log" gate --body x --verdict MAYBE 2>/dev/null || { echo "FAIL: bad verdict accepted"; exit 1; }
! "$B/team-log" gate --verdict DECIDE 2>/dev/null || { echo "FAIL: gate without topic accepted"; exit 1; }
# round limit: two decisions already went to planner/t1 -> the 3rd is refused; other task or agent is not
[ "$(G "${base[@]}" --to planner --task t1 | head -1)" = "ESCALATE ROUND_LIMIT" ] || { echo "FAIL: ROUND_LIMIT"; exit 1; }
[ "$(G "${base[@]}" --to planner --task t2 | head -1)" = "DECIDE" ] || { echo "FAIL: ROUND_LIMIT leaked across tasks"; exit 1; }
[ "$(G "${base[@]}" --to backend --task t1 | head -1)" = "DECIDE" ] || { echo "FAIL: ROUND_LIMIT leaked across agents"; exit 1; }
# report + tui understand the new fields
r=$("$B/team-report" g7); grep -q "decided by user" <<<"$r" && grep -q "gate: DECIDE" <<<"$r" && grep -q "decided by: master 1 / user 1 / policy 0" <<<"$r" || { echo "FAIL: report gate/decided_by: $r"; exit 1; }
rm -f "$TEAM_HOME/team.db"; "$B/team-tui" --dump g7 >/dev/null || { echo "FAIL: tui with gate events"; exit 1; }
# policy card: SessionStart + every 6th prompt, only for the active feature's main thread
SS='{"hook_event_name":"SessionStart","source":"compact","cwd":"'"$T"'"}'
out=$(echo "$SS" | "$B/team-hook")
jq -e '.hookSpecificOutput.hookEventName=="SessionStart" and (.hookSpecificOutput.additionalContext|test("MASTER of feature g7")) and (.hookSpecificOutput.additionalContext|test("team-gate")) and (.hookSpecificOutput.additionalContext|test("plan.md"))' <<<"$out" >/dev/null || { echo "FAIL: SessionStart card: $out"; exit 1; }
! grep -q '{{' <<<"$out" || { echo "FAIL: card placeholders left"; exit 1; }
cards=""; for i in 1 2 3 4 5 6 7 8; do o=$(MO '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"p'$i'"}'); if [ -n "$o" ]; then cards="${cards}C"; else cards="${cards}."; fi; done
[ "$cards" = "C.....C." ] || { echo "FAIL: card cadence '$cards' (want C.....C.)"; exit 1; }
jq -e '.hookSpecificOutput.hookEventName=="UserPromptSubmit"' <<<"$(M '{"hook_event_name":"SessionStart","cwd":"'"$T"'"}'; MO '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"after reset"}')" >/dev/null || { echo "FAIL: SessionStart did not reset the cadence"; exit 1; }
[ -z "$(echo '{"hook_event_name":"SessionStart","agent_id":"x1","agent_type":"agent-team:qa","cwd":"'"$T"'"}' | "$B/team-hook")" ] || { echo "FAIL: card leaked to a subagent"; exit 1; }
"$B/team-log" feature_end --feature g7
[ -z "$(echo "$SS" | "$B/team-hook")" ] || { echo "FAIL: card with no active feature"; exit 1; }
# planner report -> plan.md (latest wins), for NEEDS_DECISION too
"$B/team-log" feature_start --feature p7 --body x
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:planner","agent_id":"pl1","cwd":"'"$T"'","last_assistant_message":"T1 do x\nDONE"}' | "$B/team-hook"
grep -q "T1 do x" .team-log/p7/plan.md || { echo "FAIL: plan.md not saved"; exit 1; }
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:planner","agent_id":"pl1","cwd":"'"$T"'","last_assistant_message":"T2 redo\nNEEDS_DECISION"}' | "$B/team-hook"
grep -q "T2 redo" .team-log/p7/plan.md && ! grep -q "T1 do x" .team-log/p7/plan.md || { echo "FAIL: plan.md not replaced"; exit 1; }
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:backend","agent_id":"b9","cwd":"'"$T"'","last_assistant_message":"DONE not a plan"}' | "$B/team-hook"
! grep -q "not a plan" .team-log/p7/plan.md || { echo "FAIL: non-planner overwrote plan.md"; exit 1; }
# hook: a repeated SubagentStop (same agent, same report) is logged once; a different report from the same agent is logged
"$B/team-log" feature_start --feature dup --body x; fd=.team-log/dup/events.ndjson
SS1='{"hook_event_name":"SubagentStop","agent_type":"agent-team:qa","agent_id":"d1","cwd":"'"$T"'","last_assistant_message":"VERDICT: PASS"}'
echo "$SS1" | "$B/team-hook"; echo "$SS1" | "$B/team-hook"
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:qa","agent_id":"d1","cwd":"'"$T"'","last_assistant_message":"VERDICT: FAIL"}' | "$B/team-hook"
echo '{"hook_event_name":"SubagentStop","agent_type":"agent-team:qa","agent_id":"d2","cwd":"'"$T"'","last_assistant_message":"VERDICT: PASS"}' | "$B/team-hook"
[ "$(jq -s '[.[]|select(.type=="worker_done")]|length' $fd)" = 3 ] || { echo "FAIL: duplicate SubagentStop logged twice / distinct reports dropped"; jq -c '[.type,.agent_id,.body]' $fd; exit 1; }
# hook: harness-injected hand-back / notification text is NOT a user_reply; a real prompt still is, and the injected one does not advance the card cadence
n=$(jq -s '[.[]|select(.type=="user_reply")]|length' $fd)
M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"<agent-message from=\"x\">\n[Subagent hand-back] report"}'
M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"<task-notification><task-id>t</task-id></task-notification>"}'
[ "$(jq -s '[.[]|select(.type=="user_reply")]|length' $fd)" = "$n" ] || { echo "FAIL: injected message logged as user_reply"; exit 1; }
M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","prompt":"a real user prompt"}'
[ "$(jq -s '[.[]|select(.type=="user_reply")]|length' $fd)" = "$((n + 1))" ] || { echo "FAIL: real prompt not logged"; exit 1; }
# regression: `team-gate ... | head -1` (closing the pipe early) must still write the gate event, every time
rm -rf .team-log/pipe; "$B/team-log" feature_start --feature pipe --body x
for i in $(seq 40); do "$B/team-gate" --topic "pipe $i" --in-ticket y --reversible y --external n --security n --needs-human n | head -1 >/dev/null || true; done
n=$(jq -s '[.[]|select(.type=="gate")]|length' .team-log/pipe/events.ndjson); [ "$n" = 40 ] || { echo "FAIL: $n/40 gate events survive a closed pipe"; exit 1; }
# scenario replay (bug 8991, the 4 open questions that used to stall the run): only the plan approval should reach the user
rm -rf .team-log/s8991; "$B/team-log" feature_start --feature s8991 --body "replay"
S() { "$B/team-gate" --to planner --task plan "$@" | head -1 || true; }   # rc 1 (ESCALATE) must not kill the test under pipefail
a=$(S --topic "scope: actor-only FE fix (A) vs realtime (B/C)" --in-ticket y --reversible y --external n --security n --needs-human n)
b=$(S --topic "remove snapshot tiles the new pack no longer declares" --in-ticket y --reversible y --external n --security n --needs-human n)
c=$(S --topic "workspace: worktree fix/8991-*" --in-ticket y --reversible y --external n --security n --needs-human n)
d=$(S --topic "BA copy for the Activate disclaimer" --in-ticket y --reversible y --external n --security n --needs-human y --placeholder y)
e=$(S --topic "also push realtime to every viewer (scope C)" --in-ticket n --reversible y --external n --security n --needs-human n)
[ "$a|$b|$c|$d|$e" = "DECIDE|DECIDE|DECIDE|ASSUME ASSUMED_PLACEHOLDER|ESCALATE OUT_OF_SCOPE" ] || { echo "FAIL: 8991 replay: $a|$b|$c|$d|$e"; exit 1; }
jq -s -e '[.[]|select(.type=="gate")]|length==5 and ([.[]|select(.verdict=="ESCALATE")]|length)==1' .team-log/s8991/events.ndjson >/dev/null || { echo "FAIL: 8991 replay log"; echo "CURRENT=$(cat .team-log/CURRENT 2>/dev/null)"; ls .team-log; echo "-- where did 'remove snapshot' go:"; grep -rl "remove snapshot" .team-log | head; jq -c '[.feature,.type,.verdict,.body]' .team-log/s8991/events.ndjson 2>&1 | head -12; exit 1; }
# ---- v0.1.15: baseline event + team-cores ----
rm -rf .team-log/bl; "$B/team-log" feature_start --feature bl --body x
! "$B/team-log" baseline --body "no verdict" 2>/dev/null || { echo "FAIL: baseline without --verdict accepted"; exit 1; }
! "$B/team-log" baseline --verdict RED 2>/dev/null || { echo "FAIL: baseline without --body accepted"; exit 1; }
"$B/team-log" baseline --verdict RED --body "abc123; pytest -n 2; red: e2e/knowledge-pack.spec.ts"
jq -s -e '[.[]|select(.type=="baseline" and .verdict=="RED")]|length==1' .team-log/bl/events.ndjson >/dev/null || { echo "FAIL: baseline event"; exit 1; }
"$B/team-tui" --dump bl | grep -q "RED" || { echo "FAIL: tui baseline verdict"; exit 1; }
M '{"hook_event_name":"PreToolUse","cwd":"'"$T"'","tool_name":"Agent","tool_input":{"subagent_type":"agent-team:backend","description":"r2","prompt":"fix","model":"opus"}}'
M '{"hook_event_name":"PreToolUse","cwd":"'"$T"'","tool_name":"Agent","tool_input":{"subagent_type":"agent-team:qa","description":"base","prompt":"baseline"}}'
jq -s -e '[.[]|select(.type=="task_assigned")|.model] == ["opus","sonnet"]' .team-log/bl/events.ndjson >/dev/null || { echo "FAIL: model override / default: $(jq -c 'select(.type=="task_assigned")|.model' .team-log/bl/events.ndjson)"; exit 1; }
"$B/team-tui" --query "select model from events where feature='bl' and type='task_assigned'" | grep -q opus || { echo "FAIL: model not in the index"; exit 1; }
C() { TEAM_NPROC=$1 TEAM_LOAD=$2 "$B/team-cores"; }
r="$(C 4 0) $(C 4 0.2) $(C 4 1.5) $(C 4 9) $(C 1 0) $(C 2 5) $(C 16 2.0)"
[ "$r" = "4 3 2 2 1 2 14" ] || { echo "FAIL: team-cores: $r"; exit 1; }
w=$("$B/team-cores"); [ "$w" -ge 1 ] && [ "$w" -le "$(nproc)" ] || { echo "FAIL: team-cores on this box: $w"; exit 1; }
unset TEAM_HOOK_RETRIES
# ---- v0.1.17: session-scoped capture, usage per agent run, PR closes the log, PR outcome ----
rm -rf .team-log/wi-777; rm -f .team-log/CURRENT .team-log/CURRENT.session
P() { M '{"hook_event_name":"UserPromptSubmit","cwd":"'"$T"'","session_id":"'"$1"'","prompt":"'"$2"'"}'; }
PATH="$T/fakebin:$PATH" P s1 "/agent-team:team-lead AB#777"
[ "$(cat .team-log/CURRENT.session)" = s1 ] || { echo "FAIL: /team-lead did not bind its session"; exit 1; }
P s2 "hi from another session"; P s1 "ok tiếp đi"
g=.team-log/wi-777/events.ndjson
jq -s -e 'map(select(.type=="user_reply"))|map(.body)==["/agent-team:team-lead AB#777","ok tiếp đi"]' $g >/dev/null \
  || { echo "FAIL: session scoping: $(jq -c 'select(.type=="user_reply")|.body' $g)"; exit 1; }
# the master re-opens the feature from a new session (resume) -> that session takes over
M '{"hook_event_name":"PostToolUse","cwd":"'"$T"'","session_id":"s3","tool_name":"Bash","tool_input":{"command":"team-log feature_start --ticket 777 --type bug --title X"},"tool_response":{"stdout":""}}'
P s3 "continued"; P s1 "old session"
jq -s -e 'map(select(.type=="user_reply"))|map(.body)|.[-1]=="continued"' $g >/dev/null || { echo "FAIL: rebind on feature_start"; exit 1; }
# worktree with NO active feature keeps its own slug
touch -d '13 hours ago' .team-log/CURRENT; ( cd .claude/worktrees/wt1 && "$B/team-log" note --body solo ); touch .team-log/CURRENT
[ -s .team-log/wt1/events.ndjson ] || { echo "FAIL: worktree slug without an active feature"; exit 1; }
# usage of an agent run, from its transcript (messages repeated per content block are counted once)
tr=$T/agent-u1.jsonl
printf '%s\n' '{"type":"user","timestamp":"2026-10-02T10:00:00.000Z"}' \
  '{"type":"assistant","timestamp":"2026-10-02T10:00:05.000Z","message":{"id":"m1","model":"claude-sonnet-5-5","usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":0,"output_tokens":7},"content":[{"type":"text","text":"x"}]}}' \
  '{"type":"assistant","timestamp":"2026-10-02T10:00:05.100Z","message":{"id":"m1","model":"claude-sonnet-5-5","usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":0,"output_tokens":7},"content":[{"type":"tool_use","name":"Bash","input":{}}]}}' \
  '{"type":"assistant","timestamp":"2026-10-02T10:01:30.000Z","message":{"id":"m2","model":"claude-sonnet-5-5","usage":{"input_tokens":5,"cache_creation_input_tokens":0,"cache_read_input_tokens":110,"output_tokens":20},"content":[{"type":"text","text":"DONE usage"}]}}' > $tr
M '{"hook_event_name":"SubagentStop","agent_type":"agent-team:qa","agent_id":"u1","cwd":"'"$T"'","agent_transcript_path":"'"$tr"'"}'
jq -s -e 'map(select(.agent_id=="u1" and .type=="worker_done"))|.[0]|.model=="claude-sonnet-5-5" and .tokens_in==115 and .tokens_cache==110 and .tokens_out==27 and .secs==90 and .turns==2' $g >/dev/null \
  || { echo "FAIL: usage: $(jq -c 'select(.agent_id=="u1")' $g)"; exit 1; }
"$B/team-tui" --query "select tokens_out, turns from events where agent_id='u1'" | grep -q "^27	2" || { echo "FAIL: usage not in the index"; exit 1; }
! "$B/team-log" note --body x --usage "1 2 3" 2>/dev/null || { echo "FAIL: bad --usage accepted"; exit 1; }
# gh pr create -> pr event + feature_end, capture stops
M '{"hook_event_name":"PostToolUse","cwd":"'"$T"'","session_id":"s3","tool_name":"Bash","tool_input":{"command":"gh pr create --draft --title t"},"tool_response":{"stdout":"https://github.com/acme/app/pull/42\n"}}'
jq -s -e 'map(select(.type=="pr"))[0].body=="https://github.com/acme/app/pull/42" and .[-1].type=="feature_end"' $g >/dev/null || { echo "FAIL: PR did not close the log"; exit 1; }
[ ! -e .team-log/CURRENT ] && [ ! -e .team-log/CURRENT.session ] || { echo "FAIL: CURRENT left after the PR"; exit 1; }
# team-outcome: logs the PR state once, again only when it changes
mkdir -p "$T/fakegh"; cat > "$T/fakegh/gh" <<'GH'
#!/usr/bin/env bash
cat "$(dirname "$0")/pr.json"
GH
chmod +x "$T/fakegh/gh"
pj() { echo '{"state":"'"$1"'","isDraft":false,"createdAt":"2026-10-01T00:00:00Z","mergedAt":'"$2"',"closedAt":null,"reviews":[{"state":"CHANGES_REQUESTED"},{"state":"APPROVED"}],"comments":[{}],"commits":[{"committedDate":"2026-09-30T00:00:00Z"},{"committedDate":"2026-10-01T05:00:00Z"}],"additions":10,"deletions":2,"changedFiles":3}' > "$T/fakegh/pr.json"; }
pj OPEN null; TEAM_GH="$T/fakegh/gh" "$B/team-outcome" >/dev/null; TEAM_GH="$T/fakegh/gh" "$B/team-outcome" >/dev/null
pj MERGED '"2026-10-03T00:00:00Z"'; TEAM_GH="$T/fakegh/gh" "$B/team-outcome" | grep -q "MERGED" || { echo "FAIL: team-outcome output"; exit 1; }
jq -s -e '[.[]|select(.type=="outcome")]|map(.verdict)==["OPEN","MERGED"] and (.[-1].body|startswith("reviews=2 changes_requested=1 comments=1 commits_after_open=1 +10/-2 files=3 days=2"))' $g >/dev/null \
  || { echo "FAIL: outcome events: $(jq -c 'select(.type=="outcome")|[.verdict,.body]' $g)"; exit 1; }
echo PASS
