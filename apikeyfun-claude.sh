#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# These model IDs are listed by the live proxy as owned_by=anthropic. With
# Claude OAuth disabled, the configured Claude backend is api.apikey.fun.
export CLIPROXY_OPUS_MODEL="${CLIPROXY_OPUS_MODEL:-claude-opus-4-6}"
export CLIPROXY_SONNET_MODEL="${CLIPROXY_SONNET_MODEL:-claude-sonnet-4-5-20250929}"
export CLIPROXY_HAIKU_MODEL="${CLIPROXY_HAIKU_MODEL:-claude-haiku-4-5-20251001}"

exec "$script_dir/cliproxy-claude.sh"
