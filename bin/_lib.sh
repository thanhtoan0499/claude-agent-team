#!/usr/bin/env bash
# Shared: resolve log root + feature slug. Sourced by team-log / team-hook / team-report.

# Log root = main repo root (worktrees share one log), override with TEAM_LOG_DIR.
team_root() {
  local cwd="${1:-$PWD}" common
  common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "$cwd"; return; }
  dirname "$common"
}

# Feature slug: $TEAM_FEATURE > worktree name (.claude/worktrees/<name>) > <root>/.team-log/CURRENT > "default"
team_feature() {
  local cwd="${1:-$PWD}" root
  [ -n "${TEAM_FEATURE:-}" ] && { echo "$TEAM_FEATURE"; return; }
  case "$cwd" in
    */.claude/worktrees/*) local rest="${cwd#*/.claude/worktrees/}"; echo "${rest%%/*}"; return ;;
  esac
  root=$(team_root "$cwd")
  if [ -s "$root/.team-log/CURRENT" ]; then head -1 "$root/.team-log/CURRENT"; else echo default; fi
}

team_log_file() {
  local cwd="${1:-$PWD}" dir
  dir="${TEAM_LOG_DIR:-$(team_root "$cwd")/.team-log}/$(team_feature "$cwd")"
  mkdir -p "$dir" && echo "$dir/events.ndjson"
}
