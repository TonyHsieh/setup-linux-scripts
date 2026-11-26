#!/usr/bin/env bash
# ==============================================================================
# scripts/kanban-watch.sh
# Purpose: Live Hermes Kanban board monitor & blocked-card diagnostics
# Usage:
#   scripts/kanban-watch.sh [--board default] [--watch | --triage] [--interval 3]
# ==============================================================================
set -euo pipefail

BOARD="default"
MODE="watch"
INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --board|-b)
      BOARD="$2"
      shift 2
      ;;
    --triage|-t|--once)
      MODE="triage"
      shift
      ;;
    --watch|-w)
      MODE="watch"
      shift
      ;;
    --interval|-i)
      INTERVAL="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--board <name>] [--watch | --triage] [--interval <seconds>]"
      echo ""
      echo "Options:"
      echo "  --board, -b <name>    Kanban board to inspect (default: default)"
      echo "  --triage, -t          Run once and show full diagnostics for blocked cards"
      echo "  --watch, -w           Continuously refresh board & blocked diagnostics (default)"
      echo "  --interval, -i <sec>  Refresh interval in seconds for --watch (default: 3)"
      exit 0
      ;;
    *)
      BOARD="$1"
      shift
      ;;
  esac
done

if ! command -v hermes >/dev/null 2>&1; then
  echo "⚠️  'hermes' CLI not found in PATH." >&2
  exit 1
fi

render_once() {
  local board_out
  board_out="$(hermes kanban --board "$BOARD" list 2>&1 | grep -v 'install out of sync' || true)"

  echo "======================================================================"
  echo "🐝 Hermes Kanban Mission Control | Board: $BOARD"
  echo "======================================================================"
  echo "$board_out"

  # Extract blocked task IDs (lines containing 'blocked' and a task ID like t_xxxxxxxx)
  local blocked_ids=()
  while IFS= read -r tid; do
    [ -n "$tid" ] && blocked_ids+=("$tid")
  done < <(echo "$board_out" | grep -E '\bblocked\b' | grep -oE 't_[a-zA-Z0-9]+' || true)

  if [ ${#blocked_ids[@]} -gt 0 ]; then
    echo ""
    echo "----------------------------------------------------------------------"
    echo "🚨 Blocked Card Diagnostics (${#blocked_ids[@]} blocked)"
    echo "----------------------------------------------------------------------"
    for tid in "${blocked_ids[@]}"; do
      echo ""
      echo "▶ Task: $tid"
      if [ "$MODE" = "triage" ]; then
        hermes kanban --board "$BOARD" show "$tid" 2>&1 | grep -v 'install out of sync' || true
      else
        hermes kanban --board "$BOARD" show "$tid" 2>&1 \
          | grep -v 'install out of sync' \
          | tail -n 12 || true
      fi
      echo "  ↳ Quick actions: hermes kanban --board $BOARD show $tid  |  hermes kanban --board $BOARD unblock $tid  |  hermes kanban --board $BOARD comment $tid \"...\""
    done
  else
    echo ""
    echo "✅ No blocked cards on board '$BOARD'."
  fi

  if [ "$MODE" = "watch" ]; then
    echo ""
    echo "----------------------------------------------------------------------"
    echo "💡 Quiet watch (redraws only on change, polls every ${INTERVAL}s | Ctrl-C to exit)"
  fi
}

notify_event() {
  local kind="$1" # "done" or "blocked"
  # 1. Terminal bell (triggers Windows Terminal / Konsole / iTerm2 tab badge & system sound)
  printf '\a'
  # 2. Optional audible chime via pulseaudio-utils (WSL2/Linux) or afplay (macOS)
  if command -v paplay >/dev/null 2>&1; then
    if [ "$kind" = "blocked" ] && [ -f /usr/share/sounds/freedesktop/stereo/dialog-warning.oga ]; then
      paplay /usr/share/sounds/freedesktop/stereo/dialog-warning.oga >/dev/null 2>&1 &
    elif [ -f /usr/share/sounds/freedesktop/stereo/complete.oga ]; then
      paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1 &
    fi
  elif command -v afplay >/dev/null 2>&1; then
    afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
  fi
}

if [ "$MODE" = "triage" ]; then
  render_once
else
  LAST_SNAPSHOT=""
  LAST_STATE=""
  while true; do
    NEW_SNAPSHOT="$(render_once)"
    if [ "$NEW_SNAPSHOT" != "$LAST_SNAPSHOT" ]; then
      # Atomic, flicker-free redraw: buffer first, then clear+print in a single write
      printf '\033[2J\033[H%s\n   Last change: %s\n' "$NEW_SNAPSHOT" "$(date '+%H:%M:%S')"

      # Detect state transitions for audible notification (skip initial startup render)
      CUR_STATE="active"
      if echo "$NEW_SNAPSHOT" | grep -q "🚨 Blocked Card Diagnostics"; then
        CUR_STATE="blocked"
      elif ! echo "$NEW_SNAPSHOT" | grep -qE '(^|\s)(ready|running|todo|review)\s'; then
        CUR_STATE="done"
      fi

      if [ -n "$LAST_STATE" ] && [ "$CUR_STATE" != "$LAST_STATE" ]; then
        if [ "$CUR_STATE" = "blocked" ] || [ "$CUR_STATE" = "done" ]; then
          notify_event "$CUR_STATE"
        fi
      fi

      LAST_SNAPSHOT="$NEW_SNAPSHOT"
      LAST_STATE="$CUR_STATE"
    fi
    sleep "$INTERVAL"
  done
fi
