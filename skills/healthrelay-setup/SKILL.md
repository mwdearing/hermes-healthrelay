---
name: healthrelay-setup
description: HealthRelay setup - connect the receiver, set the database path, check it works. Read-only Apple Health access for this agent.
license: Apache-2.0
compatibility: Needs your own HealthRelay receiver (health-bridge) and an iPhone app you built and signed yourself.
---

# HealthRelay setup

This plugin only READS. It does not include the receiver or the iPhone app.

Where the plugin lives: Hermes installs it under its home directory, `~/.hermes/plugins/` by default, in a folder named after the plugin manifest, `healthrelay`, not the repository (`${HERMES_HOME:-$HOME/.hermes}/plugins/healthrelay`). `hermes plugins list` shows whether it is installed and enabled. The launcher to run by hand is `bin/healthrelay-mcp` inside that folder.

1. Receiver and app: follow https://github.com/mwdearing/health-relay (README "Set up the bridge"). The iPhone app is an unsigned IPA the user signs with their own certificate; there is no App Store listing. Use the latest STABLE release, not a beta. The `health-bridge` command must be on the PATH that Hermes runs with.
2. Tell the plugin where the receiver database is (the file `health-bridge receiver start --db ...` uses): write the path on ONE line to `~/.config/healthrelay/db-path`. The file must be in the HOME of the Hermes process, because the MCP server gets that HOME (on a plain host your normal HOME; in Docker it can differ from the agent terminal's HOME, so compare the `home used for db-path` line of the check with the Hermes process). This file is the only supported route; environment variables exported in the Hermes shell do not reach the plugin. Do not put the path in any repo or shared file.
3. Enable the plugin (`hermes plugins enable healthrelay`).
4. Run the check in a terminal: `"${HERMES_HOME:-$HOME/.hermes}/plugins/healthrelay/bin/healthrelay-mcp" --check`. It prints the HOME it read the db-path file from, the database source, path and readability, the `health-bridge` it found on PATH and its version, and ends with `result: OK (could start)` (exit 0) or `result: NOT READY ...` (exit 2). Fix what it names, then run it again. Add `--json` to the same command (`--check --json`) when a script or another agent has to read the result: that prints one JSON object on stdout with the same keys as named fields (`home`, `db_path_file`, `db_path_file_found`, `database_source`, `database_path`, `database_readable`, `launcher`, `health_bridge_version`, `schema`, `result`) and the same exit codes, instead of the text report.
5. Start a NEW Hermes session. The MCP server only loads at session start, so a db-path file written mid-session is not picked up until then. If the check is OK but the healthrelay tools are still missing in the new session, load the `healthrelay-troubleshoot` skill.
6. Verify with `get_bridge_status`, then `list_synced_metrics`. A healthy setup shows recent syncs and a non-empty metric list.

Three readiness questions
Answer each separately; one passing does not imply another.

| Question | Passes when | Does not tell you |
| --- | --- | --- |
| Launch readiness | The launcher starts and `bin/healthrelay-mcp --check` ends `result: OK (could start)`. It checks only the db-path file / `HEALTHRELAY_DB` source, that the database file exists and is readable, `health-bridge` on PATH, and its version. With `--check --json` the same answer is one JSON object with `"result": "ok"` (exit 0) or `"result": "not_ready"` (exit 2). | The schema line is informational and never changes the exit code or the result. |
| Schema readiness | `--check` also prints one `schema:` line when a readable database path is set: `intake context ready (migrations 013, 014)`, `intake context not available (receiver older than migration 013/014)`, `not checked (database unreadable as SQLite)` or `not checked (sqlite3 not found)`. | It reads only the migration list, never your data, and never changes the exit code. |
| Freshness readiness | Data arrived recently: `get_bridge_status` (last sync per lane) and `list_synced_metrics`. | Stale data with launch and schema fine is a phone/sync problem, not a launcher problem. |

Never paste the database path, pairing codes or tokens into chat logs, notes or issues.
