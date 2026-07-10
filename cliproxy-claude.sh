#!/usr/bin/env bash
set -euo pipefail

SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"
BACKUP_DIR="${CLAUDE_SETTINGS_BACKUP_DIR:-$HOME/.claude/backups}"
CLIPROXY_BASE_URL="${CLIPROXY_BASE_URL:-http://10.0.0.20:8317}"
CLIPROXY_SSH_HOST="${CLIPROXY_SSH_HOST:-starfleetubuntu}"
CLIPROXY_REMOTE_CONFIG="${CLIPROXY_REMOTE_CONFIG:-/data/docker/cliproxyapi/config.yaml}"

OPUS_MODEL="${CLIPROXY_OPUS_MODEL:-claude-opus-4-6}"
SONNET_MODEL="${CLIPROXY_SONNET_MODEL:-claude-sonnet-4-6}"
HAIKU_MODEL="${CLIPROXY_HAIKU_MODEL:-claude-haiku-4-5-20251001}"

fetch_api_key() {
  if [[ -n "${CLIPROXY_API_KEY:-}" ]]; then
    printf '%s' "$CLIPROXY_API_KEY"
    return
  fi

  ssh "$CLIPROXY_SSH_HOST" "python3 - '$CLIPROXY_REMOTE_CONFIG'" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
in_api_keys = False
for line in path.read_text().splitlines():
    if line.startswith("api-keys:"):
        in_api_keys = True
        continue
    if in_api_keys:
        if line and not line.startswith((" ", "-")):
            break
        stripped = line.strip()
        if stripped.startswith("-"):
            value = stripped[1:].strip()
            if value:
                print(value)
                sys.exit(0)

sys.exit("No api-keys entry found in " + str(path))
PY
}

validate_proxy() {
  local token="$1"
  python3 - "$CLIPROXY_BASE_URL" "$token" "$SONNET_MODEL" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base_url, token, sonnet_model = sys.argv[1:4]
url = base_url.rstrip("/") + "/v1/models"
request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})

try:
    with urllib.request.urlopen(request, timeout=8) as response:
        payload = json.loads(response.read().decode("utf-8"))
except urllib.error.HTTPError as exc:
    sys.exit(f"Proxy validation failed: HTTP {exc.code} from {url}")
except Exception as exc:
    sys.exit(f"Proxy validation failed: {exc}")

models = {item.get("id") for item in payload.get("data", []) if isinstance(item, dict)}
if sonnet_model not in models:
    visible = ", ".join(sorted(m for m in models if m)[:12])
    sys.exit(f"Proxy validation failed: model {sonnet_model!r} not visible. First models: {visible}")
PY
}

write_settings() {
  local token="$1"
  mkdir -p "$BACKUP_DIR" "$(dirname "$SETTINGS_FILE")"
  if [[ -f "$SETTINGS_FILE" ]]; then
    local backup="$BACKUP_DIR/settings.json.$(date '+%Y%m%d-%H%M%S').before-cliproxy"
    cp -p "$SETTINGS_FILE" "$backup"
    chmod 600 "$backup"
  fi

  SETTINGS_FILE="$SETTINGS_FILE" \
  CLIPROXY_BASE_URL="$CLIPROXY_BASE_URL" \
  CLIPROXY_API_KEY="$token" \
  OPUS_MODEL="$OPUS_MODEL" \
  SONNET_MODEL="$SONNET_MODEL" \
  HAIKU_MODEL="$HAIKU_MODEL" \
  python3 <<'PY'
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

env.update({
    "ANTHROPIC_BASE_URL": os.environ["CLIPROXY_BASE_URL"].rstrip("/"),
    "ANTHROPIC_AUTH_TOKEN": os.environ["CLIPROXY_API_KEY"],
    "ANTHROPIC_DEFAULT_OPUS_MODEL": os.environ["OPUS_MODEL"],
    "ANTHROPIC_DEFAULT_SONNET_MODEL": os.environ["SONNET_MODEL"],
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": os.environ["HAIKU_MODEL"],
})

# Keep Claude Code 1.x fallbacks aligned in case an older binary is launched.
env["ANTHROPIC_MODEL"] = os.environ["SONNET_MODEL"]
env["ANTHROPIC_SMALL_FAST_MODEL"] = os.environ["HAIKU_MODEL"]

tmp_path = settings_path.with_name(settings_path.name + ".tmp")
tmp_path.write_text(json.dumps(data, indent=2) + "\n")
os.chmod(tmp_path, 0o600)
os.replace(tmp_path, settings_path)
os.chmod(settings_path, 0o600)
PY
}

api_key="$(fetch_api_key)"
validate_proxy "$api_key"
write_settings "$api_key"

echo "Claude Code is now configured to use CLIProxyAPI at $CLIPROXY_BASE_URL."
echo "Start a new Claude Code session for the settings change to take effect."
