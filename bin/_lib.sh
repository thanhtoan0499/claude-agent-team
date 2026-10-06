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

# Claude Code session this process belongs to: the hook passes its payload's session_id as TEAM_SESSION; a team-log that the
# master or an agent runs from Bash inherits CLAUDE_CODE_SESSION_ID from Claude Code (the same id).
team_session() { echo "${TEAM_SESSION:-${CLAUDE_CODE_SESSION_ID:-}}"; }

# Session -> feature: .team-log/sessions/<session id> holds the feature that session runs. Two sessions can run two tickets in
# one repo at the same time; one repo-wide CURRENT cannot tell their events apart (the other session's feature_start
# re-points it, its feature_end deletes it, and the first ticket's agents log into the wrong ticket or a stray worktree slug).
team_binding() { local s; s=$(team_session); [ -n "$s" ] || return 1; echo "$(team_root "${1:-$PWD}")/.team-log/sessions/$s"; }
team_bound_feature() {
  local b cur; b=$(team_binding "$1") || return 0
  if [ -s "$b" ]; then head -1 "$b"; return 0; fi
  cur="$(team_root "${1:-$PWD}")/.team-log/CURRENT"   # pre-0.1.24 binding: CURRENT.session names this session -> it runs CURRENT
  if [ -s "$cur" ] && [ "$(cat "$cur.session" 2>/dev/null)" = "$(team_session)" ]; then head -1 "$cur"; fi
  return 0
}
team_bind() {  # <feature> [cwd]: this session runs <feature> from now on; a session that ran it before (resumed elsewhere) no longer does
  local b o; [ -n "$1" ] && b=$(team_binding "${2:-$PWD}") || return 0
  { mkdir -p "$(dirname "$b")" && echo "$1" > "$b"; } 2>/dev/null || return 0
  for o in "$(dirname "$b")"/*; do [ "$o" != "$b" ] && [ "$(head -1 "$o" 2>/dev/null)" = "$1" ] && rm -f "$o"; done; return 0
}

# Feature slug: $TEAM_FEATURE > this session's feature > worktree named after a ticket (serving-8810) -> the feature tracking it
# > active CURRENT (touched < 12 h) > worktree name (.claude/worktrees/<name>) > stale CURRENT > "default".
# The builders run in a worktree named after the branch (fix-8991); their events must land in the ticket's feature
# (bug-8991-...), not in a second slug per worktree.
team_feature() {
  local cwd="${1:-$PWD}" cur f wt="" n
  [ -n "${TEAM_FEATURE:-}" ] && { echo "$TEAM_FEATURE"; return; }
  f=$(team_bound_feature "$cwd"); [ -n "$f" ] && { echo "$f"; return; }
  case "$cwd" in */.claude/worktrees/*) wt="${cwd#*/.claude/worktrees/}"; wt="${wt%%/*}";; esac
  n=$(grep -oE '[0-9]{3,}' <<<"$wt" | head -1 || true)
  if [ -n "$n" ]; then f=$(team_ticket_feature "$n" "$cwd"); [ -n "$f" ] && { echo "$f"; return; }; fi
  cur="$(team_root "$cwd")/.team-log/CURRENT"
  if [ -s "$cur" ] && [ -n "$(find "$cur" -mmin -720 2>/dev/null)" ]; then head -1 "$cur"; return; fi
  [ -n "$wt" ] && { echo "$wt"; return; }
  if [ -s "$cur" ]; then head -1 "$cur"; else echo default; fi
}

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
