#!/bin/sh
# Self-check for drift.sh: it must stay quiet for an edit outside the cited lines and report one inside.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir"
git init -q
fail() { echo "FAIL: $*" >&2; exit 1; }
expect() {
  want=$1; text=$2; shift 2
  got=0; sh "$here/drift.sh" "$@" > out 2>&1 || got=$?
  if [ "$got" != "$want" ] || ! grep -q "$text" out; then cat out; fail "expected exit $want and '$text', got $got: $*"; fi
}
code() { printf 'header\nfn refresh() {\n  %s\n  %s\n}\nfooter %s\n' "$1" "$2" "$3" > code.rs; }

expect 2 "no VERIFY.md"
code "take_lock();" "save();" 1
cat > VERIFY.md <<'MD'
# Record

covered:
  - code.rs
    > fn refresh(
    > take_lock(
    > save(

Text after.
MD
expect 1 "code.rs: not synced yet (lines 2-4)"
expect 0 "code.rs: lines 2-4" --sync
grep -q '^  - code.rs [0-9a-f]\{12\}$' VERIFY.md || fail "--sync wrote no hash"
grep -q '^Text after\.$' VERIFY.md || fail "--sync lost text outside the block"
expect 0 "in sync"
code "take_lock();" "save();" 2
expect 0 "in sync"
code "take_lock(); log();" "save();" 2
expect 1 "code.rs: changed (lines 2-4)"
code "save();" "take_lock();" 2
expect 1 "code.rs: cited line is missing or moved: save("
expect 1 "cited line is missing" --sync
rm code.rs
expect 1 "code.rs: file is gone"

# A blank line or another indent inside the block must not drop an entry in silence.
code "take_lock();" "save();" 1
cp code.rs other.rs
printf 'covered:\n  - code.rs\n    > take_lock(\n\n   - other.rs\n     > save(\n\nText after.\n' > VERIFY.md
expect 0 "other.rs: lines 4-4" --sync
grep -q '^   - other.rs [0-9a-f]\{12\}$' VERIFY.md || fail "--sync wrote no hash for the entry after a blank line"
grep -q '^Text after\.$' VERIFY.md || fail "--sync lost text after a block with a blank line"
# A checkout with CRLF line ends has the same hash.
for file in code.rs VERIFY.md; do awk '{ printf "%s\r\n", $0 }' "$file" > crlf && mv crlf "$file"; done
expect 0 "in sync"
expect 0 "synced" --sync
[ "$(grep -c "$(printf '\r')\$" VERIFY.md)" = "$(grep -c '' VERIFY.md)" ] || fail "--sync changed the line ends of the record"
# A block that names no file is an error, not a record to skip.
printf 'covered:\n- code.rs\n' > VERIFY.md
expect 1 "VERIFY.md: the covered block names no file"
# The paths of a record start at the repo root, so a run from a subfolder says so.
mkdir sub
(cd sub && expect 2 "from the root of the repo" ../VERIFY.md)
echo "ok"
