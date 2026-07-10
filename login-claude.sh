#!/usr/bin/env bash
set -euo pipefail

SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"
BACKUP_DIR="${CLAUDE_SETTINGS_BACKUP_DIR:-$HOME/.claude/backups}"

mkdir -p "$BACKUP_DIR" "$(dirname "$SETTINGS_FILE")"
if [[ -f "$SETTINGS_FILE" ]]; then
  backup="$BACKUP_DIR/settings.json.$(date '+%Y%m%d-%H%M%S').before-login"
  cp -p "$SETTINGS_FILE" "$backup"
  chmod 600 "$backup"
fi

SETTINGS_FILE="$SETTINGS_FILE" python3 <<'PY'
import json
import os
from pathlib import Path

settings_path = Path(os.environ["SETTINGS_FILE"]).expanduser()
if settings_path.exists():
    data = json.loads(settings_path.read_text())
else:
    data = {}

env = data.get("env")
if not isinstance(env, dict):
    env = {}
data["env"] = env

for key in [
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "ANTHROPIC_MODEL",
    "ANTHROPIC_SMALL_FAST_MODEL",
]:
    env.pop(key, None)

tmp_path = settings_path.with_name(settings_path.name + ".tmp")
tmp_path.write_text(json.dumps(data, indent=2) + "\n")
os.chmod(tmp_path, 0o600)
os.replace(tmp_path, settings_path)
os.chmod(settings_path, 0o600)
PY

echo "Claude Code is now configured to use its normal login credentials."
echo "Start a new Claude Code session for the settings change to take effect."
