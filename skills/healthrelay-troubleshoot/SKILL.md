---
name: healthrelay-troubleshoot
description: "HealthRelay troubleshooting: missing, stale or wrong health data, sync stalled, empty metrics, MCP server not starting."
license: Apache-2.0
---

# HealthRelay troubleshooting

Work from the outside in and change nothing until you know the cause.

1. Start with the launcher check in a terminal: `~/.hermes/plugins/hermes-healthrelay/bin/healthrelay-mcp --check` (the plugin folder is under `~/.hermes/plugins/`; `hermes plugins list` shows it). `result: NOT READY` (exit 2) names the problem: no db-path file, unreadable database, or `health-bridge` not on PATH. See the `healthrelay-setup` skill. Then read the last lines of `~/.hermes/logs/mcp-stderr.log` (or `hermes logs mcp`) for the server's own error. If the healthrelay tools do not exist in this session at all, the server failed to start: fix it, then start a NEW session.
2. If the tools exist, call `get_bridge_status`. It shows the last sync per lane. A database error mentioning "could not be read" means the path in `~/.config/healthrelay/db-path` is wrong or the file is unreadable.
3. Nothing new arrives: if the receiver is up but the phone is not sending, check the app's Activity Log on the phone (lane names are shown on each row) and that Automatic Sync is on.
4. One lane stuck behind others: the app's upload outbox is strictly first-in-first-out, so one permanently rejected item (an HTTP 4xx from the receiver) blocks every lane queued behind it. Look at the receiver's own log (its terminal output, or the journal of the service you run it as) for the rejected request; the app shows only sanitized text.
5. Unexpected values (for example weight around 17 kg): check units and sources with `explain_sources`; report a data-quality problem, do not average it away.
6. Blood oxygen, ECG, medication and lab data need their own app lanes and Health permissions; confirm the permission and the lane before assuming the watch is not recording.
7. A tool call that fails with a date or timestamp message: see the date rules in the `healthrelay-review` skill.

Never share pairing codes, tokens or the database path when asking for help.
