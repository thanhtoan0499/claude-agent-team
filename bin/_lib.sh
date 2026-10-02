#!/usr/bin/env bash
# Shared: resolve log root + feature slug. Sourced by team-log / team-hook / team-report.

# Log root = main repo root (worktrees share one log), override with TEAM_LOG_DIR.
team_root() {
  local cwd="${1:-$PWD}" common
  common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "$cwd"; return; }
  dirname "$common"
}

# Shared index folder (~/.claude/agent-team): team.db + the list of repos whose .team-log it indexes. TEAM_HOME overrides (tests).
team_home() { echo "${TEAM_HOME:-$HOME/.claude/agent-team}"; }

# Remember this log folder so team-tui / team-retro can show it from anywhere. Never fails the caller: logging comes first.
team_register() {
  local dir="$1" reg; reg="$(team_home)/repos"
  grep -qxF "$dir" "$reg" 2>/dev/null && return 0
  { mkdir -p "$(team_home)" && printf '%s\n' "$dir" >> "$reg"; } 2>/dev/null || true
}

# Version of the plugin this script belongs to (stamped on every event, so a retro can compare before/after an upgrade).
team_version() {
  sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$(dirname "${BASH_SOURCE[0]}")/../.claude-plugin/plugin.json" 2>/dev/null | head -1 || true
}

# Feature slug: $TEAM_FEATURE > active CURRENT (touched < 12 h) > worktree name (.claude/worktrees/<name>) > stale CURRENT > "default".
# An active feature wins over the worktree name: the team's builders run in a worktree named after the branch (fix-8991), and
# their events must land in the ticket's feature (bug-8991-...), not in a second slug per worktree.
team_feature() {
  local cwd="${1:-$PWD}" cur
  [ -n "${TEAM_FEATURE:-}" ] && { echo "$TEAM_FEATURE"; return; }
  cur="$(team_root "$cwd")/.team-log/CURRENT"
  if [ -s "$cur" ] && [ -n "$(find "$cur" -mmin -720 2>/dev/null)" ]; then head -1 "$cur"; return; fi
  case "$cwd" in
    */.claude/worktrees/*) local rest="${cwd#*/.claude/worktrees/}"; echo "${rest%%/*}"; return ;;
  esac
  if [ -s "$cur" ]; then head -1 "$cur"; else echo default; fi
}

# Claude Code session bound to the active feature: only that session's main-thread events (user prompts, briefs, questions)
# are the team's. Another session in the same repo (plugin work, a "hi") must not leak into the ticket's log.
team_session_file() { echo "$(team_root "${1:-$PWD}")/.team-log/CURRENT.session"; }

# Usage of one subagent run from its transcript: "<model> <in> <cache> <out> <secs> <turns>" (in = uncached input incl. cache
# writes, cache = cache reads). Each API message is written once per content block, so messages are de-duplicated by id.
team_usage() {
  jq -rs '[.[] | select(.type=="assistant" and .message.usage != null)] as $a
    | ($a | unique_by(.message.id)) as $m
    | [.[] | .timestamp // empty | sub("\\.[0-9]+Z$";"Z") | fromdateiso8601] as $t
    | if ($m|length)==0 then empty else
      [ ($m | last | .message.model // "?"),
        ($m | map(.message.usage | (.input_tokens//0) + (.cache_creation_input_tokens//0)) | add),
        ($m | map(.message.usage.cache_read_input_tokens//0) | add),
        ($m | map(.message.usage.output_tokens//0) | add),
        (if ($t|length)>1 then ($t|max) - ($t|min) else 0 end),
        ($m|length) ] | map(tostring) | join(" ") end' "$1" 2>/dev/null
}

team_log_file() {
  local cwd="${1:-$PWD}" dir
  dir="${TEAM_LOG_DIR:-$(team_root "$cwd")/.team-log}/$(team_feature "$cwd")"
  mkdir -p "$dir" && echo "$dir/events.ndjson"
}

# ASCII kebab slug of a title (Vietnamese diacritics folded, max 60 chars).
team_slug() {
  python3 - "$1" <<'PY'
import re, sys, unicodedata
s = sys.argv[1].replace("đ", "d").replace("Đ", "D")
s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
print(re.sub(r"[^a-z0-9]+", "-", s).strip("-")[:60].rstrip("-"))
PY
}

# Feature that already tracks ticket $1: the current one if it matches, else the most recently active whose slug
# contains the ticket number as a whole token (bug-8991-x, wi-8991, x-8991). Empty if none.
team_ticket_feature() {
  local id=$1 cwd="${2:-$PWD}" root dir f d cur
  root=$(team_root "$cwd"); dir="${TEAM_LOG_DIR:-$root/.team-log}"; cur="$root/.team-log/CURRENT"
  if [ -s "$cur" ] && head -1 "$cur" | grep -qE "(^|-)${id}(-|\$)"; then head -1 "$cur"; return 0; fi
  for f in $(ls -t "$dir"/*/events.ndjson 2>/dev/null); do
    d=$(basename "$(dirname "$f")")
    if grep -qE "(^|-)${id}(-|\$)" <<<"$d"; then echo "$d"; return 0; fi
  done
  return 0
}
