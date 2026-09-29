---
name: healthrelay-setup
description: Use when the user wants to connect Apple Health to this agent through HealthRelay - install and pair the receiver and iPhone app, point this plugin at the receiver database, and verify the first sync.
license: Apache-2.0
compatibility: Needs your own HealthRelay receiver (health-bridge) and an iPhone app you built and signed yourself.
---

# HealthRelay setup

This plugin only READS. It does not include the receiver or the iPhone app.

1. Receiver and app: follow https://github.com/mwdearing/health-relay (README "Set up the bridge"). The iPhone app is an unsigned IPA the user signs with their own certificate; there is no App Store listing. Use the latest STABLE release, not a beta.
2. Point the plugin at the receiver database (the file `health-bridge receiver start --db ...` uses). Do not put the path in any repo or shared file. Either:
   - `export HEALTHRELAY_DB=/path/to/device.sqlite` for the Hermes process, or
   - write the path on one line to `~/.config/healthrelay/db-path`.
   If `health-bridge` is not on PATH, set `HEALTHRELAY_HOME` to the health-relay checkout so the launcher can use `uv run`.
3. Enable the plugin (`hermes plugins enable healthrelay`), then start a new session so the MCP server loads.
4. Verify with `get_bridge_status`, then `list_synced_metrics`. A healthy setup shows recent syncs and a non-empty metric list. If not, load the `healthrelay-troubleshoot` skill.

Never paste the database path, pairing codes or tokens into chat logs, notes or issues.
