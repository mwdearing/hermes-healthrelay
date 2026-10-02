---
name: healthrelay-review
description: Apple Health review through HealthRelay - summaries, trends, workouts, sleep, sync gaps. Read-only, aggregates first, no medical advice.
license: Apache-2.0
---

# Reviewing Apple Health data with HealthRelay

Tools (all read-only): `get_bridge_status`, `get_bridge_context_markdown`, `list_supported_timeseries_types`, `list_synced_metrics`, `get_timeseries`, `get_workouts`, `get_sleep_summary`, `get_daily_summary`, `explain_sources`, `get_intake_evidence_v1`.

Date and type rules
- `start_date` is inclusive and `end_date` is EXCLUSIVE: for one day use `2026-06-03` to `2026-06-04`. Equal dates give an empty window.
- Days are UTC days; `get_daily_summary` uses the device's calendar day when the app recorded one.
- `get_timeseries` takes UTC timestamps ending in Z, like `2026-06-01T00:00:00Z`, with `start_time` included and `end_time` excluded.
- `type_codes` must come from `list_synced_metrics`. `workout` and `sleep_analysis` are not valid there: use `get_workouts` and `get_sleep_summary`.
- Results cap at 500 rows; `truncated: true` means narrow the range or ask for fewer types.

Method
1. Start with `get_bridge_status` and `list_synced_metrics` so you know what exists and how fresh it is. Say plainly when data is stale or a metric is missing; never invent values.
2. Prefer `get_daily_summary`, `get_sleep_summary` and `get_workouts` over raw `get_timeseries`. Use a bounded date range and ask for more only when needed.
3. Use `explain_sources` when two sources disagree or a number looks odd (for example a step count from both watch and phone).
4. Report aggregates, ranges and changes with the dates they cover. Convert units to the user's preference (ask once if unknown).
5. Flag data quality problems (single outlier samples, missing days, mixed units) instead of averaging them in silently.

Intake evidence (`get_intake_evidence_v1`, read-only)
- Args: `owner_id` (optional; defaults to the single registered owner; error when none or several are registered), `intake_id` (limit to one intake), `cursor` (the previous `next_cursor`, pass unchanged), `limit` (1-500, default 100). A bad cursor, bad limit or unknown argument gives an error naming the problem.
- Result: `items[]` and `next_cursor` (null = last page). Item: producer_id, intake_id, revision, component_id, kind, code, amount (decimal string), unit, value_state, sample_uuid, healthkit_type, writer_bundle_id, client_record_id, link_status, complete. Metadata and identifiers only, no sample values.
- Two producers may share an intake_id, so always read producer_id too. Only the newest accepted revision of an intake appears; deleted intakes are excluded.

| link_status | Meaning |
| --- | --- |
| verified | Stored sample matches by exact id, quantity type and registered writer |
| pending | No stored sample with that id yet (export may not have arrived) |
| unlinked | Component has no active link |
| mismatch | Claimed sample conflicts with stored data: other quantity type, other writer or writer missing, another component claims the same sample, or the sample was deleted at its source and will never arrive |

- `complete` is false for every item of a component with an active link not yet verified. A component with no link is complete (nothing awaited).
- Unknown is not zero. pending, unlinked or complete:false is missing evidence, never a zero intake; say what is unknown.
- mismatch: report it, do not fix or reinterpret the data. Repair is a re-sync from the phone app (open the app, run a sync, query again). Never edit the database.

Limits
- Informational only. Do not diagnose, prescribe or change medication. Suggest they discuss concerns with a clinician.
- Health data is private: do not send it to web tools, third-party services, public issues or shared notes. Keep raw values out of logs unless the user asks.
- The server exposes no raw SQL and no write tools; do not try to work around that.
