# AGENTS.md

## Purpose

This repository contains shell scripts that switch Claude Code settings and a
native macOS menu bar wrapper around those scripts.

## Source of truth

- Root-level `*.sh` files are the editable switch implementations.
- `Sources/ClaudeToggle/main.swift` defines the menu bar UI and invokes the
  bundled scripts by filename.
- `Makefile` builds the app and copies the root scripts into its bundle.
- `build/ClaudeToggle.app/Contents/Resources/Scripts/` is generated output. Do
  not edit it directly.
- `README.md` is the human setup and usage guide.

## Script behavior

- `status-claude.sh` reads the active mode and must never print credentials.
- `cliproxy-claude.sh` obtains an API key, validates `/v1/models`, backs up the
  existing settings, and atomically updates `~/.claude/settings.json`.
- `antigravity-claude.sh` and `apikeyfun-claude.sh` set model defaults, then
  delegate to `cliproxy-claude.sh`.
- `login-claude.sh` removes only proxy-related environment keys and preserves
  unrelated Claude Code settings.

Keep secrets out of source files, examples, command output, and commits. Never
add CLIProxyAPI configuration, OAuth files, Claude credentials, or real API
keys.

## Updating Claude compatibility

When Claude Code changes its supported settings or installation behavior:

1. Verify the current Claude Code documentation and installed version.
2. Update both proxy-write and login-cleanup key lists together.
3. Preserve unrelated keys in `~/.claude/settings.json`.
4. Preserve atomic writes, `0600` permissions, and pre-change backups.
5. Update `status-claude.sh`, the Swift status parser, and `README.md` if visible
   status or mode behavior changes.

## Updating model mappings

1. Query the configured CLIProxyAPI `/v1/models` endpoint without exposing its
   bearer token.
2. Confirm the provider ownership and exact model IDs from the live response.
3. Update the relevant root script defaults.
4. Keep environment overrides working for every model slot.
5. Update the model examples in `README.md` if necessary.
6. Rebuild the app so its bundled scripts match the root scripts.

## Verification

Use temporary files and explicit environment overrides when testing scripts; do
not overwrite the developer's real Claude settings merely to test a change.

```bash
tmpdir="$(mktemp -d)"
CLAUDE_SETTINGS_FILE="$tmpdir/settings.json" ./status-claude.sh
CLAUDE_SETTINGS_FILE="$tmpdir/settings.json" ./login-claude.sh
bash -n ./*.sh
make clean app
codesign --verify --deep --strict build/ClaudeToggle.app
```

Proxy-switch tests also require a reachable CLIProxyAPI instance and an API key.
Pass them through `CLIPROXY_BASE_URL` and `CLIPROXY_API_KEY`; never record the
key in test fixtures or logs.

After changing a script, inspect the corresponding file under
`build/ClaudeToggle.app/Contents/Resources/Scripts/` to confirm the build copied
the new version. After changing menu actions or labels, launch the app and
manually exercise the affected action.

## Documentation rules

- Keep `README.md` task-oriented and usable by someone without access to the
  original author's network.
- Treat the CLIProxyAPI repository as the authority for its installation and
  OAuth commands; verify those instructions before changing this README.
- Keep `CLAUDE.md` as a pointer to this file rather than duplicating guidance.
