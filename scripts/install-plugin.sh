#!/usr/bin/env bash
# Local install for Cursor plugin development. Registers in ~/.claude/ so Cursor picks it up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_NAME="agent-ambient-music"
PLUGIN_ID="${PLUGIN_NAME}@local"
TARGET="$HOME/.cursor/plugins/$PLUGIN_NAME"
CLAUDE_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# 1. Copy plugin files
rm -rf "$TARGET"
mkdir -p "$TARGET"
for dir in .cursor-plugin hooks assets; do
  [[ -d "$PLUGIN_ROOT/$dir" ]] && cp -R "$PLUGIN_ROOT/$dir" "$TARGET/"
done
cp "$PLUGIN_ROOT/README.md" "$TARGET/" 2>/dev/null || true

# 2. Register in installed_plugins.json (upsert)
mkdir -p "$(dirname "$CLAUDE_PLUGINS")"
python3 - "$CLAUDE_PLUGINS" "$PLUGIN_ID" "$TARGET" <<'PY'
import json, os, sys
path, pid, ipath = sys.argv[1], sys.argv[2], sys.argv[3]
ipath = os.path.abspath(ipath)
data = {}
if os.path.exists(path):
    try: data = json.load(open(path))
    except: data = {}
plugins = data.get("plugins", {})
entries = [e for e in plugins.get(pid, []) if not (isinstance(e, dict) and e.get("scope") == "user")]
entries.insert(0, {"scope": "user", "installPath": ipath})
plugins[pid] = entries
data["plugins"] = plugins
json.dump(data, open(path, "w"), indent=2)
PY

# 3. Enable in settings.json (upsert)
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
python3 - "$CLAUDE_SETTINGS" "$PLUGIN_ID" <<'PY'
import json, os, sys
path, pid = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try: data = json.load(open(path))
    except: data = {}
data.setdefault("enabledPlugins", {})[pid] = True
json.dump(data, open(path, "w"), indent=2)
PY

# 4. Add hooks to ~/.cursor/hooks.json (Cursor doesn't load plugin hooks from plugins)
CURSOR_HOOKS="$HOME/.cursor/hooks.json"
mkdir -p "$HOME/.cursor"
HOOKS_ROOT="$TARGET/hooks"
python3 - "$CURSOR_HOOKS" "$HOOKS_ROOT" <<'PY'
import json, os, sys
path, hooks_root = sys.argv[1], sys.argv[2]
data = {"version": 1, "hooks": {}}
if os.path.exists(path):
    try: data = json.load(open(path))
    except: pass
cmds = [
    ("beforeSubmitPrompt", os.path.join(hooks_root, "session-start.sh")),
    ("stop", os.path.join(hooks_root, "force-stop.sh")),
    ("afterAgentResponse", os.path.join(hooks_root, "force-stop.sh")),
    ("sessionEnd", os.path.join(hooks_root, "force-stop.sh")),
]
for ev, cmd in cmds:
    entries = data.get("hooks", {}).get(ev, [])
    entries = [e for e in entries if not (isinstance(e, dict) and "agent-ambient" in str(e.get("command", "")))]
    entries.append({"command": cmd})
    data.setdefault("hooks", {})[ev] = entries
json.dump(data, open(path, "w"), indent=2)
PY

echo "Installed to $TARGET"
echo "Hooks added to ~/.cursor/hooks.json"
echo "→ Restart Cursor (or Cmd+Shift+P → Reload Window)"
echo ""
echo "If plugin still doesn't show: Settings > Features > enable 'Include third-party Plugins, Skills, and other configs'"
