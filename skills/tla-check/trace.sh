#!/bin/sh
# Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
# Check that a TLA+ model can follow a log of what the real code did.
# usage: sh trace.sh TRACESPEC.tla LOG [CONFIG.cfg] [extra TLC options]
# LOG has one event per line, each a TLA+ expression such as [action |-> "Read", thread |-> "t1"].
# TRACESPEC.tla extends the model and TraceLog, the module that this script writes from LOG. SKILL.md has its shape.
# Exit code: 0 the model follows the whole log, 1 it cannot, 2 the log, the trace spec, or the config is wrong,
# 12 a rule of the model breaks on the way, other values are TLC's.
set -eu
[ $# -ge 2 ] || { echo "usage: sh trace.sh TRACESPEC.tla LOG [CONFIG.cfg] [extra TLC options]" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
spec=$1; log=$2; shift 2
case ${1:--} in -*) cfg=${spec%.tla}.cfg ;; *) cfg=$1; shift ;; esac
for file in "$spec" "$log" "$cfg"; do [ -f "$file" ] || { echo "trace.sh: no such file: $file" >&2; exit 2; }; done
# TLC looks for a module next to the spec first, so a TraceLog.tla there would be read in place of the log.
stale=$(dirname "$spec")/TraceLog.tla
[ ! -e "$stale" ] || { echo "trace.sh: remove $stale; TLC would read it in place of $log" >&2; exit 2; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# TLC reports the first rule in the config that a state breaks, so the end of the log must come last.
! grep -q TraceUnfinished "$cfg" || { echo "trace.sh: take TraceUnfinished out of $cfg; this script adds it" >&2; exit 2; }
{ cat "$cfg"; echo; echo "INVARIANT TraceUnfinished"; } > "$tmp/trace.cfg"
grep '[^[:space:]]' "$log" > "$tmp/events" || { echo "trace.sh: $log has no events, so it shows nothing" >&2; exit 2; }
events=$(grep -c . "$tmp/events")
{ echo "---- MODULE TraceLog ----"; echo "TraceLog == <<"; sed '$!s/$/,/' "$tmp/events"; echo ">>"; echo "===="; } > "$tmp/TraceLog.tla"

# TLC stops at the first state that breaks TraceUnfinished, which is a state at the end of the log.
status=0
JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -DTLA-Library=$tmp" sh "$here/check.sh" "$spec" "$tmp/trace.cfg" \
  -workers 1 -deadlock -dump "$tmp/states" "$@" > "$tmp/out" 2>&1 || status=$?
if [ "$status" = 12 ] && grep -q '^Error: Invariant TraceUnfinished is violated' "$tmp/out"; then
  echo "ok: the model follows all $events events of $log"
elif [ "$status" = 0 ]; then
  at=$(sed -n 's/^\/\\ traceAt = //p' "$tmp/states.dump" | sort -n | tail -n 1)
  [ -n "$at" ] || { echo "trace.sh: TraceInit allows no first state, so the model cannot start" >&2; exit 2; }
  echo "FAIL: the model follows the first $at of $events events of $log, and cannot take event $((at + 1)):"
  sed -n "$((at + 1))p" "$tmp/events"
  echo "A state of the model before that event:"
  awk -v at="$at" '/^State / { if (hit) exit; state = "" } { state = state $0 "\n" }
    $0 == "/\\ traceAt = " at { hit = 1 } END { if (hit) printf "%s", state }' "$tmp/states.dump" | sed '1d; /^$/d'
  exit 1
else
  cat "$tmp/out"
  exit "$status"
fi
