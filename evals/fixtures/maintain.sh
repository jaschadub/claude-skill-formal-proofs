#!/bin/sh
# Builds ./counter: the plugin's counter example in a repo of its own, then a commit that changes
# hit(). $1 is "rename" (no change in behavior) or "nolock" (a race).
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
g() { git -c user.name=dev -c user.email=dev@example.org "$@"; }
# The agent's shell has no network: fetch TLC into the run's home now, as tla-check would.
sh "$root/skills/tla-check/check.sh" "$root/examples/counter/Counter.tla" >/dev/null
mkdir -p counter/examples && cp -R "$root/examples/counter" counter/examples/ && cd counter
git init -q -b main && g add . && g commit -qm "Hit counter with its verification"
f=examples/counter/counter.py
case $1 in
  rename) sed -i 's/seen/current/g' $f; msg="Rename seen to current" ;;
  nolock) sed -i '/^    with lock:$/d; s/^        \(seen = count\|count = seen + 1\)$/    \1/' $f; msg="Drop the lock from hit(); it was slow" ;;
esac
g commit -qam "$msg"
