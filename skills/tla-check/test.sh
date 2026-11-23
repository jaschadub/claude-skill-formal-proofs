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
# A relative TLA2TOOLS or JAVA is relative to the caller's folder, not to the folder of the spec.
mkdir "$dir/tools"
set -- "${XDG_CACHE_HOME:-$HOME/.cache}"/tla-check/tla2tools-*.jar
ln -s "${TLA2TOOLS:-$1}" "$dir/tools/tla2tools.jar"
printf '#!/bin/sh\nexec java "$@"\n' > "$dir/tools/java"
chmod +x "$dir/tools/java"
(cd "$dir/tools" && TLA2TOOLS=tla2tools.jar JAVA=./java expect 0 "$dir/Counter.tla")

# trace.sh: the model follows a log of real steps, and names the first event that it cannot take.
cat > "$dir/CounterTrace.tla" <<'TLA'
---- MODULE CounterTrace ----
EXTENDS Counter, Sequences, TraceLog
VARIABLE traceAt
Event(e) == e.action = "Up" /\ Up
TraceInit == Init /\ traceAt = 0
TraceNext == traceAt < Len(TraceLog) /\ Event(TraceLog[traceAt + 1]) /\ traceAt' = traceAt + 1
TraceUnfinished == traceAt < Len(TraceLog)
====
TLA
printf 'INIT TraceInit\nNEXT TraceNext\nINVARIANT AtMostThree\n' > "$dir/CounterTrace.cfg"
printf 'INIT TraceInit\nNEXT TraceNext\nINVARIANT AtMostTwo\n' > "$dir/Strict.cfg"
trace() {
  want=$1; shift
  got=0; sh "$here/trace.sh" "$dir/CounterTrace.tla" "$@" > "$dir/out" 2>&1 || got=$?
  [ "$got" = "$want" ] || { cat "$dir/out"; echo "FAIL: expected exit $want, got $got: trace $*" >&2; exit 1; }
}
has() { grep -q "$1" "$dir/out" || { cat "$dir/out"; echo "FAIL: $2" >&2; exit 1; }; }
up='[action |-> "Up"]'
printf '%s\n\n%s\n' "$up" "$up" > "$dir/log"
trace 0 "$dir/log"
has '^ok: the model follows all 2 events' "trace not accepted"
printf '%s\n%s\n%s\n%s\n' "$up" "$up" "$up" "$up" > "$dir/log"
trace 1 "$dir/log"
has 'follows the first 3 of 4 events' "the event that the model cannot take is not named"
has '^/\\ x = 3$' "no state of the model before that event"
# A rule that breaks in the last state of the log counts, though that state also ends the log.
printf '%s\n%s\n%s\n' "$up" "$up" "$up" > "$dir/log"
trace 12 "$dir/log" "$dir/Strict.cfg"
has 'Invariant AtMostTwo is violated' "broken rule not named"
: > "$dir/log"
trace 2 "$dir/log"
echo "ok"
