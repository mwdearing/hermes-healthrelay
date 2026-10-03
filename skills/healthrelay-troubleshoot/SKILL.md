---
name: healthrelay-troubleshoot
description: HealthRelay troubleshooting - missing, stale or wrong health data, sync stalled, empty metrics, MCP server not starting.
license: Apache-2.0
---

# HealthRelay troubleshooting

Work from the outside in and change nothing until you know the cause.

First decide which of three readiness questions is failing.

Answer each separately; one passing does not imply another.

| Question | Passes when | Does not tell you |
| --- | --- | --- |
| Launch readiness | The launcher starts and `bin/healthrelay-mcp --check` ends `result: OK (could start)`. It checks only the db-path file / `HEALTHRELAY_DB` source, that the database file exists and is readable, `health-bridge` on PATH, and its version. | The schema line is informational and never changes the exit code or the result. |
| Schema readiness | The receiver database has the migrations the tools need. `--check` reports it in one `schema:` line when a readable database path is set: `intake context ready (migrations 013, 014)`, `intake context not available (receiver older than migration 013/014)`, `not checked (database unreadable as SQLite)` or `not checked (sqlite3 not found)`. For intake context that means migrations 013 (`013_intake_context.sql`: intake_producers, intake_state, intake_revisions, intake_compound_facts, intake_blend_members, intake_projection_snapshots, intake_sample_links, intake_operation_receipts, intake_tombstones) and 014 (`014_intake_context_tokens.sql`: intake_context_tokens). | An older receiver gives an empty intake answer, not an error. Tell by: `tools/list` (the session tool list) lacks `get_intake_evidence_v1`, or the tool reports "no intake owner registered". Fix: upgrade the receiver to a release that includes the intake evidence tool, let it migrate, then start a NEW session. A `not checked` line means the launcher could not read the migration list, so it proves nothing either way. |
| Freshness readiness | Data arrived recently: `get_bridge_status` (last sync per lane) and `list_synced_metrics`. | Stale data with launch and schema fine is a phone/sync problem (steps 3-4), not a launcher problem. |

Steps:

1. Start with the launcher check in a terminal: `"${HERMES_HOME:-$HOME/.hermes}/plugins/healthrelay/bin/healthrelay-mcp" --check` (`hermes plugins list` shows the plugin name; the folder is named after it). The check reads `~/.config/healthrelay/db-path` from ITS shell's HOME and prints that HOME; the MCP server uses the Hermes process's HOME, which in Docker can differ from the agent terminal's. A `db-path (missing)` from the agent terminal does not prove the server has no path. `result: NOT READY` (exit 2) names the problem: no db-path file, unreadable database, or `health-bridge` not on PATH. See the `healthrelay-setup` skill. Then read the last lines of `~/.hermes/logs/mcp-stderr.log` (or `hermes logs mcp`) for the server's own error. If the healthrelay tools do not exist in this session at all, the server failed to start: fix it, then start a NEW session. If the log says `mcp package not installed`, the environment was rebuilt without the `mcp` extra (seen on images with no recorded extras): run `hermes pm install --extra mcp`, then start a new session. `hermes mcp list` and `hermes mcp test` do not show plugin-declared servers; use `hermes logs mcp` or the session tool list.
2. When you are scripting the diagnosis or another agent reads the result, use `--check --json`: one JSON object on stdout (`home`, `db_path_file`, `db_path_file_found`, `database_source`, `database_path`, `database_readable`, `launcher`, `health_bridge_version`, `schema`, `result`) and nothing else, with the same exit codes as the text report. Read `database_source` for `environment` (a `HEALTHRELAY_DB` exported by hand, which the MCP server does not see), `db_path_file` or `none`; `db_path_file_found` for whether the file is readable from this HOME; `database_readable` for the database file itself; `launcher` and `health_bridge_version` for the receiver on PATH (`null` when absent); `schema` for `ready`, `not_available` or `not_checked`; and `result` for `ok` (exit 0) or `not_ready` (exit 2).
3. If the tools exist, call `get_bridge_status`. It shows the last sync per lane. A database error mentioning "could not be read" means the path in `~/.config/healthrelay/db-path` is wrong or the file is unreadable.
4. Nothing new arrives: if the receiver is up but the phone is not sending, check the app's Activity Log on the phone (lane names are shown on each row) and that Automatic Sync is on.
5. One lane stuck behind others: the app's upload outbox is strictly first-in-first-out, so one permanently rejected item (an HTTP 4xx from the receiver) blocks every lane queued behind it. Look at the receiver's own log (its terminal output, or the journal of the service you run it as) for the rejected request; the app shows only sanitized text.
6. Unexpected values (for example weight around 17 kg): check units and sources with `explain_sources`; report a data-quality problem, do not average it away.
7. Blood oxygen, ECG, medication and lab data need their own app lanes and Health permissions; confirm the permission and the lane before assuming the watch is not recording.
8. A tool call that fails with a date or timestamp message: see the date rules in the `healthrelay-review` skill.

Never share pairing codes, tokens or the database path when asking for help.
