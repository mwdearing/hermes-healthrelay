# hermes-healthrelay

A [Hermes Agent](https://github.com/NousResearch/hermes-agent) plugin that gives your agent **read-only** access to your own Apple Health data through a self-hosted [HealthRelay](https://github.com/mwdearing/health-relay) receiver.

It is a portable Agent Plugins v1 package: one stdio MCP server plus three skills. It does **not** contain the receiver or the iPhone app.

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
~/.hermes/plugins/hermes-healthrelay/bin/healthrelay-mcp --check
```
`--check` prints the database source, path and readability, the `health-bridge` launcher and version, and ends with `result: OK` (exit 0) or `result: NOT READY` (exit 2). The MCP server only loads at session start. Clearer tool descriptions and error messages arrive with the next HealthRelay receiver release.

## What you get
| Piece | Purpose |
| --- | --- |
| MCP server `healthrelay` | Nine read-only tools, listed below |
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

Date ranges use `YYYY-MM-DD` with an inclusive start and an EXCLUSIVE end (one day is `2026-06-03` to `2026-06-04`); timestamps look like `2026-06-01T00:00:00Z`.

## Uninstall
```bash
hermes plugins uninstall hermes-healthrelay
rm -f ~/.config/healthrelay/db-path    # optional: forget the database path
```
Use the folder name that `hermes plugins list` shows if it differs. This removes the plugin only; the receiver, its database and the iPhone app are untouched.

## License
Apache-2.0. Not affiliated with Apple. Informational only, not medical advice.
