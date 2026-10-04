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

Optional: intake context (a nutrition or supplement app)
The receiver side lives in health-relay, so these commands run on the receiver host, not through this plugin. Only needed when the user wants intake context; the measurement path works without it. Intake evidence needs a receiver with migrations 013 and 014, which arrive with the pinned receiver release `healthrelay-receiver-2026.10.04` (any newer receiver from health-relay `main` has them too); an older receiver returns an empty answer. Install that exact release with `uv tool install "git+https://github.com/mwdearing/health-relay.git@healthrelay-receiver-2026.10.04"`, then continue with the steps below.
1. Register the app once as a producer: `health-bridge receiver intake-register-producer --db <db> --owner-id <id> --producer-id <id> --writer-bundle-id <bundle> --label <label>`. It is idempotent for identical details and fails closed on a different writer bundle or label. Registering a revoked producer fails and names `intake-reactivate-producer`.
2. Issue its token into a private file: `health-bridge receiver intake-create-token --db <db> --owner-id <id> --producer-id <id> --label <label> --output-secret <private file>`. Prefer --output-secret and avoid `--print-secret`: stdout then carries only the token prefix and the path, and the file is created mode 0600. Only a hash is stored. Never paste, print, share or send the token, and never read the file back into chat; tell the user where the file is so they can move the token into the app themselves.
3. Start (or restart) the receiver with `--enable-intake-context` on `health-bridge receiver start --db <db>`. The batch routes are off by default and answer 404 until the flag is passed. Add `--request-timeout <seconds>` to bound one HTTP request (over 0, at most 300; default 30).
4. Check the receiver really serves them: `health-bridge receiver intake-smoke --url <receiver URL> --token-file <file>`. It reads the token from the file, prints one JSON line with the HTTP status and the capability fields, and exits 0 on 200. It deliberately bypasses `HTTP_PROXY` and `HTTPS_PROXY` (the intake token is never sent through a proxy) and refuses redirects, so a 200 really came from your own receiver. A receiver is only ready for the app when its capabilities list `upsert`, `delete` and `link_projection`.
5. Inspect evidence locally: `health-bridge query intake-evidence --db <db> [--intake-id <id>] [--all]`. Read-only, same JSON as the `get_intake_evidence_v1` MCP tool.
6. Revoke or rotate with `health-bridge receiver intake-list-tokens` (prefixes only), `intake-revoke-token --token-prefix <prefix>`, `intake-revoke-producer` (retires the producer and every token it owns) and `intake-reactivate-producer` (restores the identity, not the credentials: issue a new token afterwards).

| `intake-smoke` says | Means | Do |
| --- | --- | --- |
| 200 | Routes enabled and the token works | Nothing; intake uploads will land |
| 404 | Routes not enabled | Restart the receiver with `--enable-intake-context` |
| 401 or 403 | Token or producer revoked | Issue a new token, or reactivate the producer |
| 429 `rate_limited` | Too many requests on this intake token | Wait the `Retry-After` seconds, then try again once (never in a retry loop) |

Rate limits and capabilities caching
The receiver limits intake per intake token, so a burst can be refused without any configuration change on your side.

- Batch uploads are limited to 60 per 60 seconds per intake token.
- Capabilities requests are limited to 30 per 60 seconds per token.
- The two budgets are separate: spending one does not consume the other.
- Over a limit the receiver answers HTTP 429 with error `rate_limited`, a `Retry-After` header in whole seconds, and closes the connection. Wait that many seconds, then make one request. Do not retry in a loop and do not send several requests at once to "get past" the limit.
- A 200 capabilities response carries `Cache-Control: private, max-age=300` and `Vary: Authorization`. A client may reuse that answer for five minutes for the same token, so a normal app does not need a capabilities GET per upload. Never share a cached capabilities answer between tokens, and never store it in a shared or public place.

Never paste the database path, pairing codes or tokens into chat logs, notes or issues.
