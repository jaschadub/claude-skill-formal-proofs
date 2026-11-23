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
echo "ok"
