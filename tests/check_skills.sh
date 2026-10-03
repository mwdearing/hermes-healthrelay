#!/bin/sh
# Lint for the skills shipped in this package. Run: sh tests/check_skills.sh
# For every skills/<name>/SKILL.md it checks that
#   - the file opens with a --- frontmatter line closed by another --- line,
#   - the frontmatter has a non-empty name: equal to the folder name,
#   - the frontmatter has a non-empty description:,
#   - every relative Markdown link target exists on disk.
# Only this package's own files are read; nothing outside the repo is touched.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
skills="$here/skills"
fail=0
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }
tmp="${TMPDIR:-/tmp}/check-skills.$$"
rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

if [ ! -d "$skills" ]; then
  bad "no skills directory at all"
  echo "RESULT: FAIL"
  exit 1
fi

count=0
for dir in "$skills"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  file="$dir/SKILL.md"
  count=$((count + 1))
  if [ ! -f "$file" ]; then
    bad "$name: SKILL.md is missing"
    continue
  fi

  # Frontmatter must be the first line, opened and closed by ---.
  if [ "$(sed -n 1p "$file")" != "---" ]; then
    bad "$name: SKILL.md does not start with a --- frontmatter line"
    continue
  fi
  if [ -z "$(awk 'NR > 1 && /^---[[:space:]]*$/ { print NR; exit }' "$file")" ]; then
    bad "$name: frontmatter is never closed by a --- line"
    continue
  fi
  front="$(awk 'NR == 1 { next } /^---[[:space:]]*$/ { exit } { print }' "$file")"
  if [ -z "$front" ]; then
    bad "$name: frontmatter between the --- lines is empty"
    continue
  fi

  # name: must be present, non-empty and equal to the folder name.
  fmname="$(printf '%s\n' "$front" | sed -n 's/^name:[[:space:]]*//p' | sed -n 1p)"
  if [ -z "$fmname" ]; then
    bad "$name: frontmatter has no non-empty name: field"
  elif [ "$fmname" != "$name" ]; then
    bad "$name: frontmatter name: '$fmname' does not match the folder name"
  else
    ok "$name: frontmatter name: matches the folder name"
  fi

  # description: must be present and non-empty (the one-line summary agents select on).
  fmdesc="$(printf '%s\n' "$front" | sed -n 's/^description:[[:space:]]*//p' | sed -n 1p)"
  if [ -z "$fmdesc" ]; then
    bad "$name: frontmatter has no non-empty description: field"
  else
    ok "$name: frontmatter has a description"
  fi

  # Relative Markdown links must resolve; absolute URLs and anchors are left alone.
  awk '{ rest = $0
         while (match(rest, /\]\([^)]*\)/)) {
           print substr(rest, RSTART + 2, RLENGTH - 3)
           rest = substr(rest, RSTART + RLENGTH)
         } }' "$file" > "$tmp/links"
  link_bad=0
  while IFS= read -r link; do
    target="${link%%#*}"
    target="${target#<}"
    target="${target%>}"
    [ -n "$target" ] || continue
    case "$target" in
      http://*|https://*|mailto:*|*/) continue ;;
    esac
    if [ -e "$dir$target" ]; then
      ok "$name: link $target exists"
    else
      bad "$name: link $target does not exist"
      link_bad=1
    fi
  done < "$tmp/links"
  [ "$link_bad" = 0 ] && ok "$name: every relative link resolves" || true
done

if [ "$count" = 0 ]; then
  bad "no skills found to lint"
else
  ok "linted $count skill(s)"
fi

[ "$fail" = 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$fail"
