#!/usr/bin/env bash
#
# Write released.json: the day each package's current build landed in this repo,
# taken from git history, so the site can show "last update" without anyone
# typing dates.
#
#   { "com.catchmind.afreecatv++": "2026-11-22", ... }
#
#  - A package's date is the newest commit touching any of its .deb files in debs/.
#  - A .deb that is staged but not committed yet (the pre-commit hook runs before
#    the commit exists) counts as today.
#  - Days are UTC and nothing else is written, so the hook and CI produce the same
#    file and CI has nothing to re-commit.
#
set -euo pipefail

DEB_DIR="debs"
OUT="released.json"

if git rev-parse --show-toplevel >/dev/null 2>&1; then
  cd "$(git rev-parse --show-toplevel)"
fi

today=$(date -u +%Y-%m-%d)

day_of() {
  local f="$1"
  # staged (new or replaced) and not yet in a commit -> today
  if ! git diff --cached --quiet -- "$f" 2>/dev/null; then
    echo "$today"; return
  fi
  local d
  d=$(TZ=UTC git log -1 --date=format-local:%Y-%m-%d --format=%cd -- "$f" 2>/dev/null || true)
  echo "${d:-$today}"
}

declare -A newest=()
shopt -s nullglob
for f in "$DEB_DIR"/*.deb; do
  pkg=$(basename "$f"); pkg=${pkg%%_*}
  d=$(day_of "$f")
  if [ -z "${newest[$pkg]:-}" ] || [[ "$d" > "${newest[$pkg]}" ]]; then
    newest[$pkg]=$d
  fi
done

{
  echo "{"
  first=1
  for pkg in $(printf '%s\n' "${!newest[@]}" | LC_ALL=C sort); do
    [ $first -eq 1 ] || echo ","
    first=0
    printf '  "%s": "%s"' "$pkg" "${newest[$pkg]}"
  done
  echo
  echo "}"
} > "$OUT"

printf '  ✓ %s: %s packages\n' "$OUT" "${#newest[@]}"
