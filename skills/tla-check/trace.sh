#!/bin/sh
# Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
# Check that a TLA+ model can follow a log of what the real code did.
# usage: sh trace.sh TRACESPEC.tla LOG [CONFIG.cfg] [extra TLC options]
# LOG has one event per line, each a TLA+ expression such as [action |-> "Read", thread |-> "t1"].
# LOG can be a folder: then every .log file under it is checked, each distinct log once, and the last lines
# say how many logs there were, how many were distinct, and how often each step was logged.
# TRACESPEC.tla extends the model and TraceLog, the module that this script writes from LOG. SKILL.md has its shape.
# Exit code: 0 the model follows the whole log, 1 it cannot, 2 the log, the trace spec, or the config is wrong,
# 12 a rule of the model breaks on the way, other values are TLC's.
set -eu
[ $# -ge 2 ] || { echo "usage: sh trace.sh TRACESPEC.tla LOG [CONFIG.cfg] [extra TLC options]" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
spec=$1; log=$2; shift 2
case ${1:--} in -*) cfg=${spec%.tla}.cfg ;; *) cfg=$1; shift ;; esac
for file in "$spec" "$cfg"; do [ -f "$file" ] || { echo "trace.sh: no such file: $file" >&2; exit 2; }; done
[ -f "$log" ] || [ -d "$log" ] || { echo "trace.sh: no such file: $log" >&2; exit 2; }
# TLC looks for a module next to the spec first, so a TraceLog.tla there would be read in place of the log.
stale=$(dirname "$spec")/TraceLog.tla
[ ! -e "$stale" ] || { echo "trace.sh: remove $stale; TLC would read it in place of $log" >&2; exit 2; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ -d "$log" ]; then
  find "$log" -type f -name '*.log' | sort > "$tmp/all"
  [ -s "$tmp/all" ] || { echo "trace.sh: no .log file under $log" >&2; exit 2; }
  # Runs that took the same steps write the same log, so check one log for each distinct text.
  if command -v sha256sum >/dev/null; then sum() { sha256sum; }; else sum() { shasum -a 256; }; fi
  while IFS= read -r file; do
    printf '%s\t%s\n' "$(grep '[^[:space:]]' "$file" | sum | cut -d' ' -f1)" "$file"
  done < "$tmp/all" | awk -F '\t' '!seen[$1]++ { print $2 }' > "$tmp/distinct"
  # One TLC for each distinct log, up to four at a time, or TLA_JOBS. Each TLC is a JVM with a heap
  # and helper threads of its own, so one for each core can use up the memory of a large machine.
  cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
  jobs=${TLA_JOBS:-$((cores < 4 ? cores : 4))}
  case $jobs in '' | *[!0-9]* | 0) echo "trace.sh: TLA_JOBS must be a positive number" >&2; exit 2 ;; esac
  n=0
  while IFS= read -r file; do
    n=$((n + 1))
    ( status=0
      sh "$here/trace.sh" "$spec" "$file" "$cfg" "$@" > "$tmp/$n.out" 2>&1 || status=$?
      echo "$status" > "$tmp/$n.status" ) &
    [ $((n % jobs)) -ne 0 ] || wait
  done < "$tmp/distinct"
  wait
  # Exit 1 says that the model cannot follow a log. Any other code is an error, and it wins.
  worst=0; bad=0; i=0
  while [ "$i" -lt "$n" ]; do
    i=$((i + 1)); status=$(cat "$tmp/$i.status")
    [ "$status" != 0 ] || continue
    bad=$((bad + 1)); cat "$tmp/$i.out"
    if [ "$worst" = 0 ] || [ "$worst" = 1 ]; then worst=$status; fi
  done
  [ "$worst" = 0 ] || { echo "FAIL: $bad of $n distinct logs under $log did not pass"; exit "$worst"; }
  echo "ok: the model follows all $(grep -c '' "$tmp/all") logs under $log, $n distinct"
  # A step with a low count is one that the runs rarely reach.
  steps=$(while IFS= read -r file; do cat "$file"; done < "$tmp/all" | sed -n 's/.*action |-> "\([^"]*\)".*/\1/p' |
    sort | uniq -c | sort -rn | awk '{ printf "%s%s %s", (NR > 1 ? ", " : ""), $1, $2 }')
  [ -z "$steps" ] || echo "steps logged: $steps"
  exit 0
fi

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
