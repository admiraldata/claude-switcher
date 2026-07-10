#!/usr/bin/env bash
set -euo pipefail

SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"

SETTINGS_FILE="$SETTINGS_FILE" python3 <<'PY'
import json
import os
from pathlib import Path

settings_path = Path(os.environ["SETTINGS_FILE"]).expanduser()
if not settings_path.exists():
    print("Mode: login credentials")
    print(f"Settings: {settings_path} does not exist")
    raise SystemExit(0)

data = json.loads(settings_path.read_text())
env = data.get("env") if isinstance(data.get("env"), dict) else {}
base_url = env.get("ANTHROPIC_BASE_URL")
auth_token_set = bool(env.get("ANTHROPIC_AUTH_TOKEN") or env.get("ANTHROPIC_API_KEY"))

if base_url:
    print("Mode: CLIProxyAPI")
    print(f"ANTHROPIC_BASE_URL: {base_url}")
    print(f"Auth token configured: {'yes' if auth_token_set else 'no'}")
    for key in [
        "ANTHROPIC_DEFAULT_OPUS_MODEL",
        "ANTHROPIC_DEFAULT_SONNET_MODEL",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        "ANTHROPIC_MODEL",
        "ANTHROPIC_SMALL_FAST_MODEL",
    ]:
        if env.get(key):
            print(f"{key}: {env[key]}")
else:
    print("Mode: login credentials")
    print("ANTHROPIC_BASE_URL: not set")
    print(f"Auth token configured: {'yes' if auth_token_set else 'no'}")
PY
