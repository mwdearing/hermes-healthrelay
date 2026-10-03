# hermes-healthrelay

A [Hermes Agent](https://github.com/NousResearch/hermes-agent) plugin that gives your agent **read-only** access to your own Apple Health data through a self-hosted [HealthRelay](https://github.com/mwdearing/health-relay) receiver.

It is a portable Agent Plugins v1 package: one stdio MCP server plus three skills. It does **not** contain the receiver or the iPhone app.

Setting up the whole chain (app and receiver, this plugin, hermes-health-insights, hermes-medlog)? Follow the [Full setup guide](https://github.com/mwdearing/health-relay/blob/main/docs/full-setup.md): one ordered walkthrough with a check after each step.

## Privacy and trust
- Your data stays on your machine. The MCP server reads your local receiver database; nothing is sent to a hosted relay.
- The MCP tools are read-only. There is no raw SQL and there are no write tools.
- Enabling any Hermes plugin grants its skills and executable full trust. Read `bin/healthrelay-mcp` (a short shell script) before enabling.
- No credentials or database paths are stored in this package.

## Install
```bash
hermes plugins install mwdearing/hermes-healthrelay --no-enable
hermes plugins enable healthrelay
```
Then follow the `healthrelay-setup` skill: install the receiver and the app from [health-relay](https://github.com/mwdearing/health-relay) (use the latest **stable** release), and write your receiver database path on one line to `~/.config/healthrelay/db-path`. That file is the one supported route; environment variables exported in the Hermes shell do not reach the plugin. Then check it and start a new Hermes session:
```bash
"${HERMES_HOME:-$HOME/.hermes}/plugins/healthrelay/bin/healthrelay-mcp" --check
```
Hermes names the install folder after the plugin manifest (`healthrelay`), not the repository; `hermes plugins list` shows the name. `--check` prints the HOME it read the db-path file from, the database source, path and readability, the `health-bridge` it found on PATH and its version, and ends with `result: OK` (exit 0) or `result: NOT READY` (exit 2). When a readable database path is set it also prints one `schema:` line saying whether the receiver has the intake-context migrations 013 and 014 (`intake context ready`, `intake context not available`, or `not checked` with the reason); that line only reads the migration list, never your data, and never changes the exit code. The db-path file must be in the HOME of the Hermes process, because that is the HOME the MCP server gets; on a plain host that is your normal HOME, in Docker it can differ from the agent terminal's HOME. The MCP server only loads at session start. Clearer tool descriptions and error messages arrive with the next HealthRelay receiver release.

Add `--json` to the same command for the machine-readable form: one JSON object on stdout, nothing else, with the same exit codes. It is meant for scripts and agents, not for reading by eye.
```bash
"${HERMES_HOME:-$HOME/.hermes}/plugins/healthrelay/bin/healthrelay-mcp" --check --json
```
```json
{"home": "/home/you", "db_path_file": "/home/you/.config/healthrelay/db-path", "db_path_file_found": true, "database_source": "db_path_file", "database_path": "/path/to/receiver.sqlite", "database_readable": true, "launcher": "/usr/local/bin/health-bridge", "health_bridge_version": "health-bridge 1.4.0", "schema": "ready", "result": "ok"}
```
`database_source` is `environment` (a `HEALTHRELAY_DB` you exported yourself), `db_path_file` or `none`; `database_path`, `launcher` and `health_bridge_version` are `null` when nothing is set; `schema` is `ready`, `not_available` or `not_checked`; `result` is `ok` (exit 0) or `not_ready` (exit 2). The plain `--check` report is unchanged.

If the healthrelay tools are missing after you enable the plugin, look in `hermes logs mcp` (or `~/.hermes/logs/mcp-stderr.log`) for `mcp package not installed`. Some images (for example the Docker image) have no recorded dependency selection, and enabling a plugin then rebuilds the environment without the `mcp` extra; run `hermes pm install --extra mcp`, then start a new session. A plain host install that already records extras keeps `mcp` and does not need this. Plugin-declared MCP servers do not appear in `hermes mcp list` or `hermes mcp test`; check `hermes logs mcp` or the tool list of a new session instead.

## Upgrade
`hermes plugins update healthrelay` refuses installs pinned to a commit. Move to a new commit with:
```bash
hermes plugins install mwdearing/hermes-healthrelay --force --ref <40-character commit sha>
```
`--force` keeps the plugin enabled or disabled as it was. Start a new session afterwards.

## What you get
| Piece | Purpose |
| --- | --- |
| MCP server `healthrelay` | Ten read-only tools, listed below |
| Skill `healthrelay-setup` | Connect the receiver and verify the first sync |
| Skill `healthrelay-review` | Answer questions with aggregates first, flag data quality, no medical advice |
| Skill `healthrelay-troubleshoot` | Find why data is missing or stale |

## Tools
| Tool | Answers |
| --- | --- |
| `get_bridge_status` | Whether the receiver is syncing: latest status, record counts, cursors |
| `get_bridge_context_markdown` | A short redacted Markdown overview of the store |
| `list_supported_timeseries_types` | Which metric types the bridge knows about, synced or not |
| `list_synced_metrics` | Which metric types have data here; the valid `type_codes` |
| `get_timeseries` | Raw samples for metric types in a UTC time range (max 500 points) |
| `get_workouts` | Workouts that started in a date range |
| `get_sleep_summary` | Sleep sessions and time per stage in a date range |
| `get_daily_summary` | Per-day totals and statistics across metrics |
| `explain_sources` | The devices and apps behind the data |
| `get_intake_evidence_v1` | Which HealthKit sample each intake component claims and whether it is stored here from the registered writer; metadata only |

Intake evidence needs a receiver with migrations 013 and 014; an older receiver returns an empty answer.

Date ranges use `YYYY-MM-DD` with an inclusive start and an EXCLUSIVE end (one day is `2026-06-03` to `2026-06-04`); timestamps look like `2026-06-01T00:00:00Z`.

## Uninstall
```bash
hermes plugins uninstall healthrelay
rm -f ~/.config/healthrelay/db-path    # optional: forget the database path
```
Use the name that `hermes plugins list` shows. This removes the plugin only; the receiver, its database and the iPhone app are untouched.

## License
Apache-2.0. Not affiliated with Apple. Informational only, not medical advice.
