# Agent Ambient Music

Cursor plugin that plays ambient music when an agent is processing. Pauses when the agent waits for input. Loops until done. Default track: "Broken Wings" (Mr. Mister), sourced from [Internet Archive](https://archive.org/details/Mr_Mister_-_Broken_wings).

## How it works

- **beforeSubmitPrompt** → plays when you send a message (agent starts processing)
- **stop** / **afterAgentResponse** / **sessionEnd** → pauses when agent finishes or waits

## Installation

### From Cursor Marketplace

1. Install from marketplace: **Settings** → **Plugins** → search "Agent Ambient Music"
2. **Run the install script** (required — Cursor doesn't load hooks from plugins):

```bash
# Find the plugin (path varies by install) and run:
find ~/.cursor/plugins -name "install-plugin.sh" -path "*agent-ambience-music*" -exec bash {} \;
```

3. **Restart Cursor**

### Local development

```bash
git clone https://github.com/joaomelorodrigues/agent-ambience-music.git
cd agent-ambience-music
./scripts/install-plugin.sh
```

Restart Cursor. Enable "Include third-party Plugins" in **Settings** → **Features** if needed.

## Track selection

Edit `~/.cursor/agent-ambient/config.json`:

```json
{
  "track": "synth",
  "customUrl": "https://example.com/your-track.mp3"
}
```

- **track**: `"default"` (bundled Broken Wings), `"synth"` (generated), `"calm"`, `"focus"` (Mixkit)
- **customUrl**: optional; URL (`https://...`) or local path (`/path/to/file.mp3` or `~/Music/ambient.mp3`)

Or set `CURSOR_AGENT_AMBIENT_URL` env var.

## Requirements

- macOS (uses `afplay`) or similar system with `afplay`-compatible player
- Python 3 (for procedural audio generation on first run, if no custom URL)

## Cache location

- Audio cache: `~/.cursor/agent-ambient/`
- Override with `CACHE_DIR` env var if needed

## Reset (music stuck)

If music plays forever:
```bash
echo 0 > ~/.cursor/agent-ambient/agent-count
~/.cursor/plugins/agent-ambient-music/hooks/session-end.sh
```
