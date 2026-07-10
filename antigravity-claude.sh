#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# These model IDs are listed by the live proxy as owned_by=antigravity.
# There is no Antigravity-owned Claude Haiku exposed, so use an Antigravity
# Gemini fast model for Claude Code's small/Haiku slot.
export CLIPROXY_OPUS_MODEL="${CLIPROXY_OPUS_MODEL:-claude-opus-4-6-thinking}"
export CLIPROXY_SONNET_MODEL="${CLIPROXY_SONNET_MODEL:-claude-sonnet-4-6}"
export CLIPROXY_HAIKU_MODEL="${CLIPROXY_HAIKU_MODEL:-gemini-3.1-flash-lite}"

exec "$script_dir/cliproxy-claude.sh"
