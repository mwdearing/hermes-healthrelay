# hermes-healthrelay

A [Hermes Agent](https://github.com/NousResearch/hermes-agent) plugin that gives your agent **read-only** access to your own Apple Health data through a self-hosted [HealthRelay](https://github.com/mwdearing/health-relay) receiver.

It is a portable Agent Plugins v1 package: one stdio MCP server plus three skills. It does **not** contain the receiver or the iPhone app.

## Privacy and trust
- Your data stays on your machine. The MCP server reads your local receiver database; nothing is sent to a hosted relay.
- The MCP tools are read-only. There is no raw SQL and there are no write tools.
- Enabling any Hermes plugin grants its skills and executable full trust. Read `bin/healthrelay-mcp` (a 20-line shell script) before enabling.
- No credentials or database paths are stored in this package.

## Install
```bash
hermes plugins install mwdearing/hermes-healthrelay --no-enable
hermes plugins enable healthrelay
```
Then follow the `healthrelay-setup` skill: install the receiver and the app from [health-relay](https://github.com/mwdearing/health-relay) (use the latest **stable** release), and point the plugin at your receiver database with `HEALTHRELAY_DB` or `~/.config/healthrelay/db-path`.

## What you get
| Piece | Purpose |
| --- | --- |
| MCP server `healthrelay` | `get_bridge_status`, `list_synced_metrics`, `get_timeseries`, `get_daily_summary`, `get_sleep_summary`, `get_workouts`, `explain_sources`, and more |
| Skill `healthrelay-setup` | Connect the receiver and verify the first sync |
| Skill `healthrelay-review` | Answer questions with aggregates first, flag data quality, no medical advice |
| Skill `healthrelay-troubleshoot` | Find why data is missing or stale |

## License
Apache-2.0. Not affiliated with Apple. Informational only, not medical advice.
