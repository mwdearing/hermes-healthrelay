#!/bin/sh
# Tests for bin/healthrelay-mcp, including --check. Run: sh tests/check_launcher.sh
# Uses a scratch HOME and a stub health-bridge; never reads real config or data.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
launcher="$here/bin/healthrelay-mcp"
root="$here/tests/.scratch"
rm -rf "$root"; mkdir -p "$root"
trap 'chmod -R u+rwx "$root" 2>/dev/null; rm -rf "$root"' EXIT
fail=0
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }
has() { case "$1" in *"$2"*) return 0;; *) return 1;; esac; }

mkdir -p "$root/bin" "$root/home/.config/healthrelay" "$root/nobin"
cat > "$root/bin/health-bridge" <<'STUB'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then echo "health-bridge 9.9.9"; exit 0; fi
echo "$*" >> "$STUB_LOG"
STUB
chmod +x "$root/bin/health-bridge"
echo synthetic > "$root/db.sqlite"
export STUB_LOG="$root/stub.log"
GOODPATH="$root/bin:/usr/bin:/bin"
BADPATH="$root/nobin:/usr/bin:/bin"

run() { # run <PATH> [env assignments via env -i style] -- args
  p="$1"; shift
  env -i HOME="$root/home" PATH="$p" STUB_LOG="$STUB_LOG" "$@"
}

sh -n "$launcher" && ok "syntax (sh -n)" || bad "syntax (sh -n)"

# 1. nothing configured
out="$(run "$GOODPATH" sh "$launcher" --check 2>&1)"; rc=$?
[ "$rc" = 2 ] && ok "1 unconfigured exits 2" || bad "1 unconfigured exits 2 (rc=$rc)"
has "$out" "database source: none" && ok "1 source none" || bad "1 source none: $out"
has "$out" "result: NOT READY" && has "$out" "~/.config/healthrelay/db-path" && ok "1 fix-it line" || bad "1 fix-it line: $out"
has "$out" "home used for db-path: $root/home" && ok "1 prints the HOME it resolved" || bad "1 prints the HOME it resolved: $out"
has "$out" "db-path file: $root/home/.config/healthrelay/db-path (missing)" && ok "1 db-path file missing" || bad "1 db-path file missing: $out"

# 2. db-path names a missing file
echo "$root/missing.sqlite" > "$root/home/.config/healthrelay/db-path"
out="$(run "$GOODPATH" sh "$launcher" --check 2>&1)"; rc=$?
[ "$rc" = 2 ] && has "$out" "database readable: no" && ok "2 missing file" || bad "2 missing file (rc=$rc): $out"

# 3. db-path names a real file, stub health-bridge on PATH
echo "$root/db.sqlite" > "$root/home/.config/healthrelay/db-path"
rm -f "$STUB_LOG"
out="$(run "$GOODPATH" sh "$launcher" --check 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "3 ready exits 0" || bad "3 ready exits 0 (rc=$rc): $out"
has "$out" "database source: db-path file" && ok "3 source" || bad "3 source: $out"
has "$out" "home used for db-path: $root/home" && ok "3 home line" || bad "3 home line: $out"
has "$out" "db-path file: $root/home/.config/healthrelay/db-path (found)" && ok "3 db-path file found" || bad "3 db-path file found: $out"
has "$out" "database path: $root/db.sqlite" && ok "3 path" || bad "3 path: $out"
has "$out" "database readable: yes" && ok "3 readable" || bad "3 readable: $out"
has "$out" "launcher: $root/bin/health-bridge" && ok "3 launcher" || bad "3 launcher: $out"
has "$out" "health-bridge version: health-bridge 9.9.9" && ok "3 version" || bad "3 version: $out"
has "$out" "result: OK" && ok "3 result OK" || bad "3 result OK: $out"
[ ! -e "$STUB_LOG" ] && ok "3 --check never starts the server" || bad "3 --check started the server: $(cat "$STUB_LOG")"

# 4. environment wins over the file
echo "$root/missing.sqlite" > "$root/home/.config/healthrelay/db-path"
out="$(run "$GOODPATH" HEALTHRELAY_DB="$root/db.sqlite" sh "$launcher" --check 2>&1)"; rc=$?
[ "$rc" = 0 ] && has "$out" "database source: environment (HEALTHRELAY_DB)" && ok "4 env source" || bad "4 env source (rc=$rc): $out"
echo "$root/db.sqlite" > "$root/home/.config/healthrelay/db-path"

# 5. no health-bridge
out="$(run "$BADPATH" /bin/sh "$launcher" --check 2>&1)"; rc=$?
[ "$rc" = 2 ] && has "$out" "launcher: none" && has "$out" "result: NOT READY" && ok "5 no health-bridge" || bad "5 no health-bridge (rc=$rc): $out"

# 6. unreadable database file
echo synthetic > "$root/locked.sqlite"; chmod 000 "$root/locked.sqlite"
echo "$root/locked.sqlite" > "$root/home/.config/healthrelay/db-path"
out="$(run "$GOODPATH" sh "$launcher" --check 2>&1)"; rc=$?
if [ "$(id -u)" = 0 ]; then ok "6 (skipped as root)"; else
  [ "$rc" = 2 ] && has "$out" "database readable: no" && ok "6 unreadable file" || bad "6 unreadable file (rc=$rc): $out"
fi
echo "$root/db.sqlite" > "$root/home/.config/healthrelay/db-path"

# 7. normal start is unchanged (no --check)
rm -f "$STUB_LOG"
run "$GOODPATH" sh "$launcher" >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && [ "$(cat "$STUB_LOG" 2>/dev/null)" = "mcp start --db $root/db.sqlite" ] && ok "7 normal start runs 'mcp start --db'" || bad "7 normal start (rc=$rc): $(cat "$STUB_LOG" 2>/dev/null)"
rm -f "$root/home/.config/healthrelay/db-path"
out="$(run "$GOODPATH" sh "$launcher" 2>&1)"; rc=$?
[ "$rc" = 2 ] && has "$out" "healthrelay: write your receiver database path to ~/.config/healthrelay/db-path" && ok "7 unconfigured start unchanged" || bad "7 unconfigured start (rc=$rc): $out"

# 8. HEALTHRELAY_HOME is not a supported route (Hermes strips it): with uv available but no health-bridge, both modes fail
echo "$root/db.sqlite" > "$root/home/.config/healthrelay/db-path"
mkdir -p "$root/uvbin"
printf '#!/bin/sh\necho "$*" >> "$STUB_LOG"\n' > "$root/uvbin/uv"; chmod +x "$root/uvbin/uv"
rm -f "$STUB_LOG"
out="$(run "$root/uvbin:/usr/bin:/bin" HEALTHRELAY_HOME="$root" sh "$launcher" --check 2>&1)"; rc=$?
[ "$rc" = 2 ] && has "$out" "launcher: none" && has "$out" "result: NOT READY" && ok "8 --check ignores HEALTHRELAY_HOME" || bad "8 --check ignores HEALTHRELAY_HOME (rc=$rc): $out"
run "$root/uvbin:/usr/bin:/bin" HEALTHRELAY_HOME="$root" sh "$launcher" >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && [ ! -e "$STUB_LOG" ] && ok "8 normal start does not use uv" || bad "8 normal start used uv or exited $rc: $(cat "$STUB_LOG" 2>/dev/null)"

# 9. docs: install folder is the manifest name, not the repo name; descriptions are unquoted
if grep -rn "plugins/hermes-healthrelay" "$here/README.md" "$here/skills" >/dev/null 2>&1; then bad "9 docs still say plugins/hermes-healthrelay"; else ok "9 no plugins/hermes-healthrelay in docs"; fi
grep -q 'plugins/healthrelay' "$here/README.md" && ok "9 README names plugins/healthrelay" || bad "9 README names plugins/healthrelay"
if grep -n '^description: "' "$here"/skills/*/SKILL.md >/dev/null 2>&1; then bad "9 quoted description in a SKILL.md"; else ok "9 descriptions unquoted"; fi
grep -q 'hermes plugins install mwdearing/hermes-healthrelay --force --ref' "$here/README.md" && ok "9 README has the --force --ref upgrade" || bad "9 README has the --force --ref upgrade"

# 10. schema line: intake-context readiness reported read-only (synthetic databases in the scratch dir)
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "NOTE 10 skipped: sqlite3 is not installed on this machine"
else
  sqlite3 "$root/new.sqlite" "create table schema_migrations (migration_id text primary key, applied_at text);
    insert into schema_migrations values ('012_lab_results','2026-10-03T00:00:00Z');
    insert into schema_migrations values ('013_intake_context','2026-10-03T00:00:00Z');
    insert into schema_migrations values ('014_intake_context_tokens','2026-10-03T00:00:00Z');
    create table samples (value real); insert into samples values (123.456);" >/dev/null 2>&1
  sqlite3 "$root/old.sqlite" "create table schema_migrations (migration_id text primary key, applied_at text);
    insert into schema_migrations values ('012_lab_results','2026-10-03T00:00:00Z');
    create table samples (value real); insert into samples values (123.456);" >/dev/null 2>&1
  echo "not a database, synthetic text" > "$root/junk.sqlite"

  out="$(run "$GOODPATH" HEALTHRELAY_DB="$root/new.sqlite" sh "$launcher" --check 2>&1)"; rc=$?
  has "$out" "schema: intake context ready (migrations 013, 014)" && ok "10 new receiver: schema ready" || bad "10 new receiver: schema ready: $out"
  [ "$rc" = 0 ] && has "$out" "result: OK" && ok "10 new receiver: exit and result unchanged" || bad "10 new receiver: exit and result unchanged (rc=$rc): $out"
  has "$out" "123.456" && bad "10 new receiver: printed a data value" || ok "10 new receiver: no data values printed"

  out="$(run "$GOODPATH" HEALTHRELAY_DB="$root/old.sqlite" sh "$launcher" --check 2>&1)"; rc=$?
  has "$out" "schema: intake context not available (receiver older than migration 013/014)" && ok "10 old receiver: schema not available" || bad "10 old receiver: schema not available: $out"
  [ "$rc" = 0 ] && has "$out" "result: OK" && ok "10 old receiver: exit and result unchanged" || bad "10 old receiver: exit and result unchanged (rc=$rc): $out"
  has "$out" "123.456" && bad "10 old receiver: printed a data value" || ok "10 old receiver: no data values printed"

  out="$(run "$GOODPATH" HEALTHRELAY_DB="$root/junk.sqlite" sh "$launcher" --check 2>&1)"; rc=$?
  has "$out" "schema: not checked (database unreadable as SQLite)" && ok "10 non-SQLite file: schema not checked" || bad "10 non-SQLite file: schema not checked: $out"
  [ "$rc" = 0 ] && has "$out" "result: OK" && ok "10 non-SQLite file: exit and result unchanged" || bad "10 non-SQLite file: exit and result unchanged (rc=$rc): $out"

  mkdir -p "$root/nosqlite"
  for t in sh head cat grep sed tr awk dirname basename printf; do
    [ -e "/usr/bin/$t" ] && ln -sf "/usr/bin/$t" "$root/nosqlite/$t"
  done
  ln -sf "$root/bin/health-bridge" "$root/nosqlite/health-bridge"
  out="$(run "$root/nosqlite" HEALTHRELAY_DB="$root/new.sqlite" sh "$launcher" --check 2>&1)"; rc=$?
  has "$out" "schema: not checked (sqlite3 not found)" && ok "10 no sqlite3 on PATH: schema not checked" || bad "10 no sqlite3 on PATH: schema not checked: $out"
  [ "$rc" = 0 ] && has "$out" "result: OK" && ok "10 no sqlite3 on PATH: exit and result unchanged" || bad "10 no sqlite3 on PATH: exit and result unchanged (rc=$rc): $out"

  rm -f "$root/home/.config/healthrelay/db-path"
  out="$(run "$GOODPATH" sh "$launcher" --check 2>&1)"
  has "$out" "schema:" && bad "10 unconfigured: printed a schema line" || ok "10 unconfigured: no schema line"
fi

# 11. --check --json: the same checks as one JSON object on stdout, same exit codes
one_line() { [ "$(printf '%s' "$1" | wc -l)" -eq 0 ]; }
shell_file="$root/home/.config/healthrelay/db-path"
echo "$root/db.sqlite" > "$shell_file"
out="$(run "$GOODPATH" sh "$launcher" --check --json 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && ok "11 ready: exit 0 like text mode" || bad "11 ready: exit 0 (rc=$rc): $out"
one_line "$out" && ok "11 ready: one line of stdout" || bad "11 ready: stdout is not a single line: $out"
case "$out" in "{"*"}") ok "11 ready: stdout is one JSON object" || bad "11 ready: stdout is not one JSON object: $out";; *) bad "11 ready: stdout is not one JSON object: $out";; esac
has "$out" "\"home\": \"$root/home\"" && ok "11 ready: home key" || bad "11 ready: home key: $out"
has "$out" "\"db_path_file\": \"$shell_file\"" && ok "11 ready: db_path_file key" || bad "11 ready: db_path_file key: $out"
has "$out" '"db_path_file_found": true' && ok "11 ready: db_path_file_found is a JSON boolean" || bad "11 ready: db_path_file_found: $out"
has "$out" '"database_source": "db_path_file"' && ok "11 ready: source from the db-path file" || bad "11 ready: source: $out"
has "$out" "\"database_path\": \"$root/db.sqlite\"" && ok "11 ready: path" || bad "11 ready: path: $out"
has "$out" '"database_readable": true' && ok "11 ready: database_readable is a JSON boolean" || bad "11 ready: database_readable: $out"
has "$out" "\"launcher\": \"$root/bin/health-bridge\"" && ok "11 ready: launcher" || bad "11 ready: launcher: $out"
has "$out" '"health_bridge_version": "health-bridge 9.9.9"' && ok "11 ready: version" || bad "11 ready: version: $out"
has "$out" '"result": "ok"' && ok "11 ready: result" || bad "11 ready: result: $out"
has "$out" '"' && ok "11 keys are quoted" || bad "11 keys are quoted: $out"
has "$out" "'" && bad "11 output contains a single quote" || ok "11 output contains no stray quote"

# 11b. plain --check output is unchanged by the new flag
out="$(run "$GOODPATH" sh "$launcher" --check 2>/dev/null)"
has "$out" "database source: db-path file (~/.config/healthrelay/db-path)" && ok "11b plain --check still text" || bad "11b plain --check still text: $out"
has "$out" "{" && bad "11b plain --check printed JSON" || ok "11b plain --check prints no JSON"

# 11c. unconfigured: JSON, exit 2, null where nothing is set
rm -f "$shell_file"
out="$(run "$GOODPATH" sh "$launcher" --check --json 2>/dev/null)"; rc=$?
[ "$rc" = 2 ] && ok "11c unconfigured: exit 2" || bad "11c unconfigured: exit 2 (rc=$rc): $out"
has "$out" '"database_source": "none"' && ok "11c unconfigured: source none" || bad "11c unconfigured: source none: $out"
has "$out" '"database_path": null' && ok "11c unconfigured: database_path null" || bad "11c unconfigured: database_path null: $out"
has "$out" '"database_readable": false' && ok "11c unconfigured: database_readable false" || bad "11c unconfigured: database_readable false: $out"
has "$out" '"db_path_file_found": false' && ok "11c unconfigured: db_path_file_found false" || bad "11c unconfigured: db_path_file_found false: $out"
has "$out" '"schema": "not_checked"' && ok "11c unconfigured: schema not_checked" || bad "11c unconfigured: schema not_checked: $out"
has "$out" '"result": "not_ready"' && ok "11c unconfigured: result not_ready" || bad "11c unconfigured: result not_ready: $out"
out="$(run "$BADPATH" sh "$launcher" --check --json 2>/dev/null)"; rc=$?
[ "$rc" = 2 ] && has "$out" '"launcher": null' && has "$out" '"health_bridge_version": null' && ok "11c no health-bridge: launcher and version null" || bad "11c no health-bridge: null launcher (rc=$rc): $out"

# 11d. a path holding a quote and a backslash is JSON-escaped
weird="$root/we\"ird\\path.sqlite"
echo synthetic > "$weird"
out="$(run "$GOODPATH" HEALTHRELAY_DB="$weird" sh "$launcher" --check --json 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && one_line "$out" && ok "11d weird path: exit 0, one line" || bad "11d weird path: exit 0, one line (rc=$rc): $out"
has "$out" "\"database_path\": \"$root/we\\\"ird\\\\path.sqlite\"" && ok "11d weird path: quote and backslash escaped" || bad "11d weird path: escaped path: $out"
has "$out" '"result": "ok"' && ok "11d weird path: still ok" || bad "11d weird path: still ok: $out"

# 11e. schema readiness in JSON: older receiver, and a file that is not a database
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "NOTE 11e skipped: sqlite3 is not installed on this machine"
else
  sqlite3 "$root/json-new.sqlite" "create table schema_migrations (migration_id text primary key, applied_at text);
    insert into schema_migrations values ('013_intake_context','2026-10-03T00:00:00Z');
    insert into schema_migrations values ('014_intake_context_tokens','2026-10-03T00:00:00Z');" >/dev/null 2>&1
  sqlite3 "$root/json-old.sqlite" "create table schema_migrations (migration_id text primary key, applied_at text);
    insert into schema_migrations values ('012_lab_results','2026-10-03T00:00:00Z');" >/dev/null 2>&1
  out="$(run "$GOODPATH" HEALTHRELAY_DB="$root/json-new.sqlite" sh "$launcher" --check --json 2>/dev/null)"; rc=$?
  has "$out" '"schema": "ready"' && [ "$rc" = 0 ] && ok "11e new receiver: schema ready" || bad "11e new receiver: schema ready (rc=$rc): $out"
  out="$(run "$GOODPATH" HEALTHRELAY_DB="$root/json-old.sqlite" sh "$launcher" --check --json 2>/dev/null)"; rc=$?
  has "$out" '"schema": "not_available"' && [ "$rc" = 0 ] && has "$out" '"result": "ok"' && ok "11e older receiver: schema not_available, exit unchanged" || bad "11e older receiver: schema not_available (rc=$rc): $out"
  out="$(run "$GOODPATH" HEALTHRELAY_DB="$root/junk.sqlite" sh "$launcher" --check --json 2>/dev/null)"; rc=$?
  has "$out" '"schema": "not_checked"' && [ "$rc" = 0 ] && ok "11e non-SQLite file: schema not_checked" || bad "11e non-SQLite file: schema not_checked (rc=$rc): $out"
  out="$(run "$root/nosqlite" HEALTHRELAY_DB="$root/json-new.sqlite" sh "$launcher" --check --json 2>/dev/null)"; rc=$?
  has "$out" '"schema": "not_checked"' && [ "$rc" = 0 ] && ok "11e no sqlite3 on PATH: schema not_checked" || bad "11e no sqlite3 on PATH: schema not_checked (rc=$rc): $out"
fi

[ "$fail" = 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$fail"
