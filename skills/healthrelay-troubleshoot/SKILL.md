---
name: healthrelay-troubleshoot
description: Use when HealthRelay data is missing, stale or wrong - sync stalled, empty metrics, upload errors, MCP server not starting.
license: Apache-2.0
---

# HealthRelay troubleshooting

Work from the outside in and change nothing until you know the cause.

1. MCP server not starting: run `bin/healthrelay-mcp` (in this plugin) in a terminal. Exit code 2 with a message means the database path or launcher is missing (see the `healthrelay-setup` skill).
2. Nothing new arrives: `get_bridge_status` shows the last sync per lane. If the receiver is up but the phone is not sending, check the app's Activity Log on the phone (lane names are shown on each row) and that Automatic Sync is on.
3. One lane stuck behind others: the app's upload outbox is strictly first-in-first-out, so one permanently rejected item (an HTTP 4xx from the receiver) blocks every lane queued behind it. Get the raw receiver response before guessing (the app shows only sanitized text).
4. Unexpected values (for example weight around 17 kg): check units and sources with `explain_sources`; report a data-quality problem, do not average it away.
5. Blood oxygen, ECG, medication and lab data need their own app lanes and Health permissions; confirm the permission and the lane before assuming the watch is not recording.

Never share pairing codes, tokens or the database path when asking for help.
