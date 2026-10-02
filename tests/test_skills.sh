#!/usr/bin/env bash
# Static checks for the role skills and their wiring into agents. usage: bash tests/test_skills.sh
# Role skill = skills/<name>/SKILL.md with `user-invocable: false` (preloaded into agents via `skills:` frontmatter).
set -euo pipefail
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
fail() { echo "FAIL: $*"; exit 1; }
MAX_SKILL=100        # lines per skill (every line is paid on every dispatch)
MAX_AGENT=340        # lines of preloaded skills per agent
# model per agent (triage.md): planner/reviewer opus, builders/qa/designer sonnet. A typo here falls back silently.
declare -A MODEL=([planner]=opus [reviewer]=opus [backend]=sonnet [frontend]=sonnet [qa]=sonnet [designer]=sonnet)
declare -A LINES

fm() { awk -v k="$2" 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1&&index($0,k": ")==1{sub(k": ","");print;exit}' "$1"; }

roles=()
for f in skills/*/SKILL.md; do
  d=$(basename "$(dirname "$f")")
  [ "$(fm "$f" name)" = "$d" ] || fail "$f: frontmatter name must equal directory name ($d)"
  desc=$(fm "$f" description); [ -n "$desc" ] || fail "$f: missing one-line description"
  [ "$(fm "$f" user-invocable)" = false ] || continue          # user-facing skills (team-lead, team-retro) are exempt
  roles+=("$d"); n=$(wc -l < "$f"); LINES[$d]=$n
  [ "${#desc}" -le 200 ] || fail "$f: description ${#desc} chars > 200 (it sits in the master's context)"
  [ "$n" -le "$MAX_SKILL" ] || fail "$f: $n lines > $MAX_SKILL"
  [ "$(fm "$f" disable-model-invocation)" != true ] || fail "$f: disable-model-invocation:true makes it impossible to preload"
  # agents cannot ask the user, cannot call Skill/WebFetch, cannot dispatch: such instructions are dead weight or harmful
  if grep -niE 'human partner|superpowers:|AskUserQuestion|ask (the|your) (user|human)|WebFetch|dispatch (a )?subagent|Task tool' "$f"; then fail "$f: contains an instruction agents cannot follow (above)"; fi
  # attribution: an "Adapted from X" comment needs a THIRD_PARTY.md entry for that source
  if grep -q 'Adapted from' "$f"; then
    src=$(grep -o 'Adapted from [A-Za-z0-9_./-]*' "$f" | head -1 | sed 's/Adapted from //; s#.*/##')
    grep -q "$src" THIRD_PARTY.md || fail "$f: adapted from '$src' but THIRD_PARTY.md has no entry"
    grep -qE '\((MIT|Apache-2.0)' "$f" || fail "$f: attribution comment lacks the licence"
  fi
done
[ "${#roles[@]}" -gt 0 ] || fail "no role skills found"

# wiring: every `skills:` entry of every agent resolves; per-agent budget
for a in agents/*.md; do
  list=$(awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} /^skills:/{s=1;next} s&&/^  - /{sub(/^  - /,"");print;next} s{exit}' "$a")
  total=0
  for s in $list; do
    s=${s#agent-team:}
    [ -f "skills/$s/SKILL.md" ] || fail "$a: skill '$s' does not exist"
    [ -n "${LINES[$s]:-}" ] || fail "$a: skill '$s' is not a role skill (user-invocable: false)"
    total=$((total + LINES[$s]))
  done
  [ "$total" -le "$MAX_AGENT" ] || fail "$a: preloaded skills total $total lines > $MAX_AGENT"
  n=$(basename "$a" .md); [ "$(fm "$a" model)" = "${MODEL[$n]:-}" ] || fail "$a: model '$(fm "$a" model)' != '${MODEL[$n]:-?}' (triage.md)"
  echo "ok  $n: $(fm "$a" model), $(echo $list | wc -w) skills, $total lines"
done
# every role skill is used by at least one agent (an orphan costs master context for nothing)
for s in "${roles[@]}"; do grep -qE "^  - (agent-team:)?$s\$" agents/*.md || fail "role skill '$s' is not loaded by any agent"; done
echo "PASS (${#roles[@]} role skills)"
