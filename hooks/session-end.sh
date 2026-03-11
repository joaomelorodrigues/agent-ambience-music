#!/usr/bin/env bash
# Stop hook: decrement count. Kill when count=0. Fallback: always kill if PID exists.

set -euo pipefail

CACHE_DIR="${CACHE_DIR:-$HOME/.cursor/agent-ambient}"
PID_FILE="$CACHE_DIR/ambient.pid"
COUNT_FILE="$CACHE_DIR/agent-count"

acquire_lock() {
  local t=0
  while ! mkdir "$CACHE_DIR/.lock" 2>/dev/null; do
    sleep 0.05; t=$((t+1))
    [ $t -gt 100 ] && rm -rf "$CACHE_DIR/.lock" 2>/dev/null; sleep 0.1
  done
}
release_lock() { rmdir "$CACHE_DIR/.lock" 2>/dev/null || true; }
acquire_lock
COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT > 0 ? COUNT - 1 : 0))
echo "$COUNT" > "$COUNT_FILE"
release_lock

# Kill if count=0, OR if count seems stuck (always kill - user MUST have music stop)
if [ "$COUNT" -gt 0 ]; then
  exit 0
fi

# Kill
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$PID" ]; then
    pkill -9 -P "$PID" 2>/dev/null || true
    kill -9 "$PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

# Fallback: kill any orphaned afplay
pkill -9 -f "afplay.*agent-ambient" 2>/dev/null || true
pkill -9 -f "afplay.*\.cursor/agent-ambient" 2>/dev/null || true
exit 0
