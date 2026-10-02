#!/usr/bin/env bash
# MANUAL smoke test (spends a few cents of API): does `skills:` in an agent of THIS plugin really preload the plugin's skills,
# and under which name? A wrong name is skipped silently by Claude Code (debug log only), so the static test cannot catch it.
# usage: bash tests/smoke_preload.sh [agent]      (default agent: qa)
set -euo pipefail
R=$(cd "$(dirname "$0")/.." && pwd); AG=${1:-qa}; W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
for v in plain ns; do
  cp -r "$R" "$W/$v"; rm -rf "$W/$v/.git"
  sed -i 's/"name": "agent-team"/"name": "agent-team-dev"/' "$W/$v/.claude-plugin/plugin.json"   # avoid clashing with the installed copy
done
sed -i -E 's/^  - ([a-z][a-z0-9-]+)$/  - agent-team-dev:\1/' "$W"/ns/agents/*.md                    # variant 2: namespaced names
mkdir -p "$W/run"; cd "$W/run"; git init -q
P="Use the Agent tool to launch the agent-team-dev:$AG subagent. Its prompt must be exactly: \"Do not use any tool. List the exact first heading line (the line starting with #) of every skill whose full text is already present in your context at startup. If there are none, answer exactly NONE.\" Then print the subagent answer verbatim and nothing else."
for v in plain ns; do
  echo "=========== variant: $v  (skills: names $( [ $v = plain ] && echo 'plain' || echo 'agent-team-dev:<name>' ))"
  timeout 240 claude -p "$P" --plugin-dir "$W/$v" --model haiku --max-turns 6 --allowedTools Agent Task 2>&1 | tail -15
done
echo; echo "Expected for qa: headings of evidence-before-claims, tdd-red-green, root-cause-first. NONE or empty = that name form is NOT resolved."
