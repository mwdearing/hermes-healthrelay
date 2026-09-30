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

[ "$fail" = 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$fail"
