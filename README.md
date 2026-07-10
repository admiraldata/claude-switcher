# Claude Switcher

Claude Switcher changes Claude Code between its normal Anthropic login and a
self-hosted [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI). You can
switch from shell scripts or from a small macOS menu bar app.

The switcher preserves unrelated Claude Code settings, backs up the current
settings before every change, and never prints the proxy API key in status
output.

## Requirements

- macOS 13 or newer for the menu bar app
- Bash, Python 3, SSH, and `make`
- Xcode Command Line Tools (for the Swift compiler used to build the app)
- Claude Code already installed and signed in
- A running CLIProxyAPI instance that this Mac can reach
- One or more Google accounts with an eligible paid Google AI plan or credits
  if you want to use Claude models provided through CLIProxyAPI's Antigravity
  integration

## 1. Set up CLIProxyAPI

Install and configure CLIProxyAPI by following its
[official setup instructions](https://github.com/router-for-me/CLIProxyAPI).
Its example configuration uses port `8317`, stores OAuth data under
`~/.cli-proxy-api`, and protects the API with keys you define in
`config.yaml`:

```yaml
port: 8317
auth-dir: "~/.cli-proxy-api"

api-keys:
  - "replace-with-a-long-random-key"
```

Add each eligible Google account to CLIProxyAPI with its Antigravity OAuth
login flow:

```bash
./CLIProxyAPI --antigravity-login
```

Run the command again for every additional Google account. Complete the OAuth
flow using the account whose paid plan or credits you intend to use. If the
proxy runs without a desktop browser, add `--no-browser` and follow the URL it
prints. CLIProxyAPI manages the authenticated accounts and selects between
them; Claude Switcher only points Claude Code at that proxy.

Start CLIProxyAPI, then confirm its model endpoint is reachable with one of the
API keys from `config.yaml`:

```bash
curl -H 'Authorization: Bearer YOUR_API_KEY' \
  http://YOUR_PROXY_HOST:8317/v1/models
```

Do not commit `config.yaml`, OAuth files, or API keys to this repository.

## 2. Install Claude Switcher

```bash
git clone https://github.com/admiraldata/claude-switcher.git
cd claude-switcher
```

The default script values describe the original installation. Other users
should provide their proxy address and API key explicitly:

```bash
export CLIPROXY_BASE_URL="http://YOUR_PROXY_HOST:8317"
export CLIPROXY_API_KEY="YOUR_API_KEY"
```

To keep those values across Terminal sessions, add the exports to your shell
profile and restrict that file appropriately. Treat `CLIPROXY_API_KEY` as a
secret.

Alternatively, omit `CLIPROXY_API_KEY` when the API key is stored on a machine
you can reach over SSH. Configure all three remote lookup values:

```bash
export CLIPROXY_SSH_HOST="your-proxy-host"
export CLIPROXY_REMOTE_CONFIG="/path/to/CLIProxyAPI/config.yaml"
export CLIPROXY_BASE_URL="http://YOUR_PROXY_HOST:8317"
```

## 3. Switch from Terminal

Check the current mode without displaying credentials:

```bash
./status-claude.sh
```

Use the general CLIProxyAPI model mapping:

```bash
./cliproxy-claude.sh
```

Use the Antigravity model mapping:

```bash
./antigravity-claude.sh
```

Use the optional apikey.fun model mapping:

```bash
./apikeyfun-claude.sh
```

Return to the normal Claude Code login:

```bash
./login-claude.sh
```

Start a new Claude Code session after switching. Each switch backs up the
previous `~/.claude/settings.json` under `~/.claude/backups/` and writes the new
settings with permissions `0600`.

### Model overrides

CLIProxyAPI model availability can change. Override any mapping without editing
a script:

```bash
CLIPROXY_OPUS_MODEL="your-opus-model" \
CLIPROXY_SONNET_MODEL="your-sonnet-model" \
CLIPROXY_HAIKU_MODEL="your-fast-model" \
./cliproxy-claude.sh
```

The switch validates that the selected Sonnet model appears in `/v1/models`
before it changes Claude Code settings.

## 4. Use the macOS menu bar app

Build and run the app:

```bash
make run
```

Install it in `/Applications`:

```bash
make install
```

Install it and start it automatically at login:

```bash
make install-autostart
```

Remove automatic startup:

```bash
make uninstall-autostart
```

The menu provides these actions:

- **Use Login Credentials**
- **Use CLIProxyAPI**
- **Use apikey.fun Pool**
- **Use Antigravity Pool**
- **Refresh Status**
- **Open Claude Settings**
- **Open Scripts Folder**

The app bundles copies of the shell scripts. Run `make app` again after changing
any script. For local development, make the app use the scripts in this checkout:

```bash
CLAUDE_TOGGLE_DIR="$PWD" open "build/ClaudeToggle.app"
```

Environment variables launched from a Terminal are not automatically available
to apps opened later from Finder. For the installed app, either use the SSH
config lookup supported by `cliproxy-claude.sh`, or launch the app from a shell
that has the `CLIPROXY_*` variables set.

## Troubleshooting

- **Proxy validation failed** — confirm the URL, API key, and that the selected
  Sonnet model appears in the proxy's `/v1/models` response.
- **The menu app fails but the script works** — make sure SSH does not require an
  interactive shell or Keychain prompt, or launch the app with the required
  `CLIPROXY_*` environment variables.
- **The mode changed but an existing session did not** — quit that Claude Code
  session and start a new one.
- **A model disappeared** — inspect `/v1/models`, update the corresponding model
  override, and switch again.

## Updating Claude Code or the switcher

Update Claude Code using the installation method recommended by its current
release, then run `./status-claude.sh` and test both login and proxy modes. Claude
Switcher edits supported environment keys in `~/.claude/settings.json`; it does
not replace or patch the Claude Code executable.

To update this project:

```bash
git pull --ff-only
make clean app
```

If the installed copy should also be replaced, run `make install` or
`make install-autostart` after the build succeeds.
