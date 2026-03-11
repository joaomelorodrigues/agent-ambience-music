#!/usr/bin/env bash
# Force stop: always kill music (used by sessionEnd when chat closes)

set -euo pipefail

CACHE_DIR="${CACHE_DIR:-$HOME/.cursor/agent-ambient}"
PID_FILE="$CACHE_DIR/ambient.pid"
COUNT_FILE="$CACHE_DIR/agent-count"

echo 0 > "$COUNT_FILE"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$PID" ]; then
    pkill -9 -P "$PID" 2>/dev/null || true
    kill -9 "$PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

# Fallback: kill any afplay from this plugin (cache or bundled assets)
pkill -9 -f "afplay.*agent-ambient" 2>/dev/null || true
pkill -9 -f "afplay.*agent-ambient-music" 2>/dev/null || true
exit 0
