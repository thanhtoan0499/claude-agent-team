#!/usr/bin/env bash
# The budget guard reminds an agent-team run once, at TEAM_TOOL_BUDGET tool calls. usage: bash tests/test_budget_guard.sh
set -euo pipefail
G=$(cd "$(dirname "$0")/../bin" && pwd)/team-budget-guard
export TMPDIR=$(mktemp -d) TEAM_TOOL_BUDGET=5; trap 'rm -rf "$TMPDIR"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
call() { jq -nc --arg a "$1" --arg i "$2" '{hook_event_name:"PreToolUse",agent_type:$a,agent_id:$i,tool_name:"Bash",tool_input:{command:"ls"}}' | "$G"; }
denied() { grep -q '"permissionDecision":"deny"' <<<"$1"; }
for k in 1 2 3 4; do out=$(call agent-team:backend r1); denied "$out" && fail "call $k denied before the budget"; done
out=$(call agent-team:backend r1); denied "$out" || fail "call 5 (= budget) not denied"
grep -q 'remaining:' <<<"$out" || fail "reminder does not ask for remaining:"
for k in 6 7 8; do out=$(call agent-team:backend r1); denied "$out" && fail "call $k denied after the reminder"; done
for k in 1 2 3 4 5; do out=$(call agent-team:qa r2); done; denied "$out" || fail "budget not counted per agent run"
for k in 1 2 3 4 5 6; do out=$(call "" m1); denied "$out" && fail "master / non-team agent denied"; done
echo PASS
