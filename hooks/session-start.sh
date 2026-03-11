#!/usr/bin/env bash
# sessionStart hook: play ambient music when agent starts processing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUNDLED_MP3="$PLUGIN_ROOT/assets/broken-wings.mp3"

CACHE_DIR="${CACHE_DIR:-$HOME/.cursor/agent-ambient}"
PID_FILE="$CACHE_DIR/ambient.pid"
COUNT_FILE="$CACHE_DIR/agent-count"
AUDIO_FILE="$CACHE_DIR/ambient.wav"

mkdir -p "$CACHE_DIR"

# Reference count: multiple agents = one music. Incr count, start only if was 0.
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
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -z "$OLD_PID" ] || ! kill -0 "$OLD_PID" 2>/dev/null; then
    COUNT=0  # Stale: no music but count > 0 (e.g. crash)
  fi
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"
release_lock

# If already playing, skip (another agent has it)
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    exit 0
  fi
  rm -f "$PID_FILE"
fi

# Generate ambient audio if not present (soft layered sine waves)
if [ ! -f "$AUDIO_FILE" ]; then
  AUDIO_FILE="$AUDIO_FILE" python3 - "$AUDIO_FILE" <<'PY'
import wave, struct, math, sys, array
path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ambient.wav'
rate = 22050
duration = 20
n = int(rate * duration)
samples = array.array('h')
tau = 2 * math.pi
for i in range(n):
    t = i / rate
    v = (0.15 * math.sin(tau * 110 * t) + 0.12 * math.sin(tau * 164 * t + 0.3) +
         0.10 * math.sin(tau * 220 * t + 0.7) + 0.08 * math.sin(tau * 55 * t * (1 + 0.01 * math.sin(0.5 * t))))
    v *= 0.4 * (1 + 0.05 * math.sin(0.1 * t))
    samples.append(max(-32767, min(32767, int(v * 32767))))
with wave.open(path, 'w') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    w.writeframes(samples.tobytes())
PY
fi

# Track selection: config file ~/.cursor/agent-ambient/config.json
# { "track": "default"|"synth"|"calm"|"focus"|"simplicity", "customUrl": "..." (optional) }
CONFIG_FILE="$CACHE_DIR/config.json"
TRACK="default"
CUSTOM_URL="${CURSOR_AGENT_AMBIENT_URL:-}"
if [ -f "$CONFIG_FILE" ]; then
  TRACK=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('track','default'))" 2>/dev/null || echo "default")
  CUSTOM_URL="${CUSTOM_URL:-$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('customUrl',''))" 2>/dev/null || true)}"
fi

# Presets: bundled, URLs (Mixkit), or customUrl for local paths
case "$TRACK" in
  default) PRESET="$BUNDLED_MP3"; PRESET_TYPE="local" ;;
  calm)    PRESET="https://assets.mixkit.co/music/preview/mixkit-serene-view-443.mp3"; PRESET_TYPE="url" ;;
  focus)   PRESET="https://assets.mixkit.co/music/preview/mixkit-a-very-small-amount-of-sugar-131.mp3"; PRESET_TYPE="url" ;;
  synth)   PRESET=""; PRESET_TYPE="" ;;
  *)       PRESET=""; PRESET_TYPE="" ;;
esac

if [ -n "$CUSTOM_URL" ]; then
  if [[ "$CUSTOM_URL" =~ ^https?:// ]]; then
    CUSTOM_FILE="$CACHE_DIR/custom.mp3"
    [ ! -f "$CUSTOM_FILE" ] && curl -sfL "$CUSTOM_URL" -o "$CUSTOM_FILE" 2>/dev/null || true
  else
    CUSTOM_FILE="${CUSTOM_URL/#\~/$HOME}"  # expand ~
  fi
  [ -f "$CUSTOM_FILE" ] && AUDIO_FILE="$CUSTOM_FILE"
elif [ -n "$PRESET" ]; then
  if [ "$PRESET_TYPE" = "local" ]; then
    [ -f "$PRESET" ] && AUDIO_FILE="$PRESET"
  else
    PRESET_FILE="$CACHE_DIR/${TRACK}.mp3"
    [ ! -f "$PRESET_FILE" ] && curl -sfL "$PRESET" -o "$PRESET_FILE" 2>/dev/null || true
    [ -f "$PRESET_FILE" ] && AUDIO_FILE="$PRESET_FILE"
  fi
fi

# Play in background, loop while agent processes (restarts when track ends)
( while true; do afplay "$AUDIO_FILE" </dev/null 2>/dev/null || true; done & echo $! ) > "$PID_FILE"
exit 0
