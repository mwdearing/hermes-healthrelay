---
name: healthrelay-review
description: Use when answering questions about the user's Apple Health data through the HealthRelay MCP tools - summaries, trends, workouts, sleep, sync gaps. Read-only, counts and aggregates first, no medical advice.
license: Apache-2.0
---

# Reviewing Apple Health data with HealthRelay

Tools (all read-only): `get_bridge_status`, `get_bridge_context_markdown`, `list_supported_timeseries_types`, `list_synced_metrics`, `get_timeseries`, `get_workouts`, `get_sleep_summary`, `get_daily_summary`, `explain_sources`.

Method
1. Start with `get_bridge_status` and `list_synced_metrics` so you know what exists and how fresh it is. Say plainly when data is stale or a metric is missing; never invent values.
2. Prefer `get_daily_summary`, `get_sleep_summary` and `get_workouts` over raw `get_timeseries`. Use a bounded date range and ask for more only when needed.
3. Use `explain_sources` when two sources disagree or a number looks odd (for example a step count from both watch and phone).
4. Report aggregates, ranges and changes with the dates they cover. Convert units to the user's preference (ask once if unknown).
5. Flag data quality problems (single outlier samples, missing days, mixed units) instead of averaging them in silently.

Limits
- Informational only. Do not diagnose, prescribe or change medication. Suggest they discuss concerns with a clinician.
- Health data is private: do not send it to web tools, third-party services, public issues or shared notes. Keep raw values out of logs unless the user asks.
- The server exposes no raw SQL and no write tools; do not try to work around that.
