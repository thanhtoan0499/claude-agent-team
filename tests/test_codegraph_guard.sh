#!/usr/bin/env bash
# The codegraph guard denies an agent's first code search before codegraph, once. usage: bash tests/test_codegraph_guard.sh
set -euo pipefail
G=$(cd "$(dirname "$0")/../bin" && pwd)/team-codegraph-guard
T=$(mktemp -d); export TMPDIR=$(mktemp -d); trap 'rm -rf "$T" "$TMPDIR"' EXIT
mkdir -p "$T/idx/.codegraph" "$T/idx/src" "$T/noidx"
fail() { echo "FAIL: $*"; exit 1; }
call() { # agent_type agent_id cwd tool command
  jq -nc --arg a "$1" --arg i "$2" --arg c "$3" --arg t "$4" --arg cmd "$5" \
    '{hook_event_name:"PreToolUse",agent_type:$a,agent_id:$i,cwd:$c,tool_name:$t,tool_input:{command:$cmd,pattern:$cmd}}' | "$G"; }
denied() { grep -q '"permissionDecision":"deny"' <<<"$1"; }

out=$(call agent-team:backend a1 "$T/idx/src" Bash "cat plan.md && sed -n 1,20p x.py"); denied "$out" && fail "reading was blocked"
out=$(call agent-team:backend a1 "$T/idx/src" Bash "cd src && grep -rn 'Foo' ."); denied "$out" || fail "first grep not denied"
out=$(call agent-team:backend a1 "$T/idx/src" Bash "grep -rn 'Foo' ."); denied "$out" && fail "second grep denied (must block once)"
out=$(call agent-team:planner a2 "$T/idx" mcp__codegraph__codegraph_explore ""); denied "$out" && fail "codegraph denied"
out=$(call agent-team:planner a2 "$T/idx" Grep "Foo"); denied "$out" && fail "grep after codegraph denied"
out=$(call agent-team:qa a3 "$T/idx" Grep "Foo"); denied "$out" || fail "first Grep tool call not denied"
out=$(call agent-team:qa a4 "$T/noidx" Bash "find . -name x"); denied "$out" && fail "denied in a repo without index"
out=$(call "" a5 "$T/idx" Bash "grep x y"); denied "$out" && fail "non-team agent denied"
out=$(call agent-team:reviewer a6 "$T/idx" Bash "git log --grep=fix -5"); denied "$out" && fail "git log --grep denied"
out=$(call agent-team:reviewer a7 "$T/idx" Bash "uv run pytest -q tests | grep FAILED"); denied "$out" && fail "grep filtering piped output denied"
out=$(call agent-team:reviewer a7 "$T/idx" Bash "find src -name '*.py' | grep foo"); denied "$out" || fail "find piped to grep not denied"
out=$(call agent-team:qa a8 "$T/idx" Bash "grep -n FAILED /tmp/run.log"); denied "$out" && fail "grep on a log file denied"
out=$(call agent-team:qa a8 "$T/idx" Bash "grep -c tool_call .team-log/x/events.ndjson docs/notes.md"); denied "$out" && fail "grep on .team-log/md denied"
out=$(call agent-team:qa a8 "$T/idx" Bash "grep -rn 'Foo' src/app.py notes.md"); denied "$out" || fail "grep naming a code file not denied"
out=$(call agent-team:qa a9 "$T/idx" Bash "grep -rn Foo"); denied "$out" || fail "grep with no path not denied"
out=$(call agent-team:backend b1 "$T/idx" Bash "a || grep -rn Foo src"); denied "$out" || fail "grep after || not denied"
echo PASS
