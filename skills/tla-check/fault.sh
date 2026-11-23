#!/bin/sh
# Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
# Show that a check can still fail: switch on one deliberate fault of a model, and require that it breaks a rule.
# usage: sh fault.sh SPEC.tla FAULT RULE [CONFIG.cfg]
# The config holds `Faults = {}`. This script checks a copy of it with `Faults = {"FAULT"}` and with RULE as
# its only rule, because TLC stops at the first rule that breaks. For a fault that must break two rules, run
# it once for each.
# Exit code: 0 the fault breaks the rule, 1 the rule holds with the fault on, 2 the config has no empty Faults
# or does not list RULE, other values are TLC's.
set -eu
[ $# -ge 3 ] || { echo "usage: sh fault.sh SPEC.tla FAULT RULE [CONFIG.cfg]" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
spec=$1; fault=$2; rule=$3; cfg=${4:-${spec%.tla}.cfg}
[ -f "$cfg" ] || { echo "fault.sh: no such file: $cfg" >&2; exit 2; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed "s/Faults *= *{ *}/Faults = {\"$fault\"}/" "$cfg" > "$tmp/on.cfg"
! cmp -s "$cfg" "$tmp/on.cfg" || { echo "fault.sh: $cfg has no 'Faults = {}' to switch on" >&2; exit 2; }
# Drop every INVARIANT and PROPERTY section, and put RULE back under the keyword that it was listed under.
awk -v rule="$rule" '
  BEGIN {
    n = split("CONSTANT CONSTANTS INIT NEXT SPECIFICATION SYMMETRY VIEW CONSTRAINT CONSTRAINTS " \
      "ACTION_CONSTRAINT ACTION_CONSTRAINTS CHECK_DEADLOCK ALIAS POSTCONDITION", words)
    for (i = 1; i <= n; i++) other[words[i]] = 1
  }
  $1 ~ /^(INVARIANTS?|PROPERTY|PROPERTIES)$/ { section = $1; $1 = "" }
  $1 in other { section = "" }
  section == "" { print; next }
  $1 !~ /^\\\*/ { for (i = 1; i <= NF; i++) if ($i == rule) found = section }
  END { if (!found) exit 1; print (found ~ /^INV/ ? "INVARIANT " : "PROPERTY ") rule }
' "$tmp/on.cfg" > "$tmp/fault.cfg" || { echo "fault.sh: $cfg does not list the rule $rule" >&2; exit 2; }

status=0
sh "$here/check.sh" "$spec" "$tmp/fault.cfg" > "$tmp/out" 2>&1 || status=$?
# 12 is a broken invariant or action property, which TLC names. 13 is a broken liveness property, which it does not.
if { [ "$status" = 12 ] && grep '^Error: ' "$tmp/out" | grep -qF " $rule is violated"; } || [ "$status" = 13 ]; then
  echo "ok: fault $fault breaks $rule"
elif [ "$status" = 0 ]; then
  echo "FAIL: $rule holds with fault $fault on, so the check cannot catch that fault"
  exit 1
else
  cat "$tmp/out"
  exit "$status"
fi
