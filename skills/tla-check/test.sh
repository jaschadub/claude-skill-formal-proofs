#!/bin/sh
# Self-check for check.sh: a rule that holds must exit 0, a rule that breaks must exit 12.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cat > "$dir/Counter.tla" <<'TLA'
---- MODULE Counter ----
EXTENDS Naturals
VARIABLE x
Init == x = 0
Up == x < 3 /\ x' = x + 1
Stop == x = 3 /\ UNCHANGED x
Next == Up \/ Stop
AtMostThree == x <= 3
AtMostTwo == x <= 2
====
TLA
printf 'INIT Init\nNEXT Next\nINVARIANT AtMostThree\n' > "$dir/Counter.cfg"
printf 'INIT Init\nNEXT Next\nINVARIANT AtMostTwo\n' > "$dir/Broken.cfg"
expect() {
  want=$1; shift
  got=0; sh "$here/check.sh" "$@" > "$dir/out" 2>&1 || got=$?
  [ "$got" = "$want" ] || { cat "$dir/out"; echo "FAIL: expected exit $want, got $got: $*" >&2; exit 1; }
}
expect 0 "$dir/Counter.tla"
expect 0 "$dir/Counter.tla" -coverage 1
grep -q '^<Up line .*>: 3:3$' "$dir/out" || { cat "$dir/out"; echo "FAIL: no action counts with -coverage" >&2; exit 1; }
expect 12 "$dir/Counter.tla" "$dir/Broken.cfg"
grep -q "Invariant AtMostTwo is violated" "$dir/out" || { echo "FAIL: counterexample not printed" >&2; exit 1; }
[ "$(ls "$dir")" = "$(printf 'Broken.cfg\nCounter.cfg\nCounter.tla\nout')" ] || { ls "$dir"; echo "FAIL: check.sh left files next to the spec" >&2; exit 1; }
echo "ok"
