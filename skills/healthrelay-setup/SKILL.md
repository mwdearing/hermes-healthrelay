---
name: healthrelay-setup
description: "HealthRelay setup: connect the receiver, set the database path, check it works. Read-only Apple Health access for this agent."
license: Apache-2.0
compatibility: Needs your own HealthRelay receiver (health-bridge) and an iPhone app you built and signed yourself.
---

# HealthRelay setup

This plugin only READS. It does not include the receiver or the iPhone app.

Where the plugin lives: Hermes installs it under its home directory, `~/.hermes/plugins/` by default, in a folder named after the repository (`~/.hermes/plugins/hermes-healthrelay`). `hermes plugins list` shows whether it is installed and enabled. The launcher to run by hand is `bin/healthrelay-mcp` inside that folder.

1. Receiver and app: follow https://github.com/mwdearing/health-relay (README "Set up the bridge"). The iPhone app is an unsigned IPA the user signs with their own certificate; there is no App Store listing. Use the latest STABLE release, not a beta. The `health-bridge` command must be on the PATH that Hermes runs with.
2. Tell the plugin where the receiver database is (the file `health-bridge receiver start --db ...` uses): write the path on ONE line to `~/.config/healthrelay/db-path`. This file is the only supported route; environment variables exported in the Hermes shell do not reach the plugin. Do not put the path in any repo or shared file.
3. Enable the plugin (`hermes plugins enable healthrelay`).
4. Run the check in a terminal: `~/.hermes/plugins/hermes-healthrelay/bin/healthrelay-mcp --check`. It prints the database source, path and readability, the launcher and `health-bridge` version, and ends with `result: OK (could start)` (exit 0) or `result: NOT READY ...` (exit 2). Fix what it names, then run it again.
5. Start a NEW Hermes session. The MCP server only loads at session start, so a db-path file written mid-session is not picked up until then. If the check is OK but the healthrelay tools are still missing in the new session, load the `healthrelay-troubleshoot` skill.
6. Verify with `get_bridge_status`, then `list_synced_metrics`. A healthy setup shows recent syncs and a non-empty metric list.

Never paste the database path, pairing codes or tokens into chat logs, notes or issues.
