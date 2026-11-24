#!/bin/sh
# Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
# Say whether verified code still matches the record in each VERIFY.md.
# usage: sh drift.sh [--sync] [VERIFY.md ...]    (default: every VERIFY.md in the repo; run from the repo root)
#
# A record holds a block like this, with paths from the repo root:
#   covered:
#     - src/session.rs 3f2a1b9c04de
#       > async fn refresh(
#       > session_lock(
# Each "> " line cites one line of the file by a piece of its text, in the order the lines appear.
# An entry and its "> " lines are indented by one space or more. The block ends at the first line that is
# neither one of those nor blank.
# The hash covers the text from the first cited line to the last, or the whole file when no line is cited.
# Each report names the record, the file, and the lines of the stretch as they are now.
# --sync writes the current hashes into the records. Run it only after the verification describes the code.
# Exit code: 0 in sync, 1 covered code changed, a cited line was not found, or a block names no file,
# 2 no record found, or not run from the repo root.
set -eu
sync=
if [ "${1:-}" = --sync ]; then sync=1; shift; fi
prefix=$(git rev-parse --show-prefix 2>/dev/null) || prefix=
[ -z "$prefix" ] || { echo "drift.sh: run it from the root of the repo, not from $prefix" >&2; exit 2; }
# Paths are split on whitespace on purpose: no spaces in the path of a record or of covered code.
# shellcheck disable=SC2046
[ $# -gt 0 ] || set -- $(git ls-files -co --exclude-standard -- ':(glob)**/VERIFY.md')
tmp=$(mktemp -d)
# The report is printed only at the end, so that a reader that stops early, as `| head` does, cannot stop
# --sync before it writes the records.
if (exec 3>&1) 2>/dev/null; then exec 3>&1; else exec 3>/dev/null; fi
trap 'cat "$tmp/out" >&3 2>/dev/null; rm -rf "$tmp"' EXIT
exec >"$tmp/out"

# Print the text of file $1 from the first line cited in $tmp/cited to the last, and its line numbers
# on stderr. If a cited line is missing or out of order, print its text and fail.
# A CR at the end of a line is dropped, so that a checkout with CRLF line ends has the same hash.
region() {
  awk -v cited="$tmp/cited" '
    BEGIN { while ((getline line < cited) > 0) want[++n] = line; i = 1 }
    { sub(/\r$/, "") }
    n == 0 { print; next }
    i <= n && index($0, want[i]) { if (i++ == 1) first = NR }
    i > 1 { text = text $0 "\n" }
    i > n { printf "%s", text; print "lines " first "-" NR > "/dev/stderr"; found = 1; exit }
    END { if (n == 0) print "whole file" > "/dev/stderr"; else if (!found) { print want[i]; exit 1 } }
  ' "$1"
}

status=2
for rec in "$@"; do
  [ -f "$rec" ] || continue
  # One "A text" line for each cited line, then one "F path hash" line for the entry they belong to.
  awk '
    function flush() { if (path != "") printf "%sF %s %s\n", cited, path, hash; path = ""; cited = "" }
    { sub(/\r$/, "") }
    /^covered:/ { flush(); on = 1; next }
    on && /^[ \t]*$/ { next }
    on && /^[ \t]+- [^ ]/ { flush(); path = $2; hash = $3; next }
    on && /^[ \t]+> / { sub(/^[ \t]+> /, ""); cited = cited "A " $0 "\n"; next }
    { flush(); on = 0 }
    END { flush() }
  ' "$rec" > "$tmp/entries"
  if [ ! -s "$tmp/entries" ]; then
    # A block that this script reads no entry from would pass as a record that covers nothing.
    if grep -q '^covered:' "$rec"; then
      echo "$rec: the covered block names no file: indent each '- path' entry and its '> text' lines"
      status=1
    fi
    continue
  fi
  [ "$status" = 1 ] || status=0
  drift=
  : > "$tmp/cited"
  : > "$tmp/hashes"
  while IFS= read -r line; do
    case $line in "A "*) printf '%s\n' "${line#A }" >> "$tmp/cited"; continue ;; esac
    entry=${line#F }; path=${entry%% *}; was=${entry#* }; why=
    if [ ! -f "$path" ]; then
      why="file is gone"
    elif ! region "$path" > "$tmp/region" 2> "$tmp/where"; then
      why="cited line is missing or moved: $(cat "$tmp/region")"
    else
      now=$(git hash-object "$tmp/region" | cut -c1-12)
      echo "$now" >> "$tmp/hashes"
      where=$(cat "$tmp/where")
      if [ -n "$sync" ]; then echo "$rec: $path: $where"
      elif [ -z "$was" ]; then why="not synced yet ($where)"
      elif [ "$now" != "$was" ]; then why="changed ($where)"
      fi
    fi
    : > "$tmp/cited"
    [ -n "$why" ] || continue
    drift=1
    echo "$rec: $path: $why"
    [ -n "$was" ] && [ -f "$path" ] || continue
    # The commit that wrote this hash into the record is the last sync: list what touched the file since.
    base=$(git log -1 --format=%h -S"$was" -- "$rec" 2>/dev/null) || base=
    {
      [ -z "$base" ] || git log --oneline "$base..HEAD" -- "$path"
      [ -z "$(git status --short -- "$path")" ] || echo "uncommitted changes"
    } 2>/dev/null | sed 's/^/    /'
  done < "$tmp/entries"
  if [ -n "$drift" ]; then
    status=1
  elif [ -n "$sync" ]; then
    awk -v hashes="$tmp/hashes" '
      /^covered:/ { on = 1; print; next }
      on && /^[ \t\r]*$/ { print; next }
      on && /^[ \t]+- [^ ]/ {
        cr = sub(/\r$/, "") ? "\r" : ""; match($0, /^[ \t]+/); getline hash < hashes
        print substr($0, 1, RLENGTH) "- " $2 " " hash cr; next
      }
      on && /^[ \t]+> / { print; next }
      { on = 0; print }
    ' "$rec" > "$tmp/new"
    cat "$tmp/new" > "$rec"
    echo "$rec: synced"
  else
    echo "$rec: in sync"
  fi
done
[ "$status" != 2 ] || echo "no VERIFY.md with a covered block found" >&2
exit "$status"
