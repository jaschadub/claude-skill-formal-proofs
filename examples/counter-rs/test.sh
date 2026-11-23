#!/bin/sh
# Self-check for the Rust example: both checks pass on the code, and both fail with the fault applied.
# It leaves the log of a real run in target/trace.log.
set -eu
cd "$(dirname "$0")"
here=$PWD
trace=$here/../../skills/tla-check/trace.sh
spec=$here/../counter/CounterTrace.tla
# The copy with the fault builds into its own target folder: with a shared one, cargo can run a stale binary.
copy=$(mktemp -d)
trap 'rm -rf "$copy"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
every_order() { RUSTFLAGS="--cfg loom" cargo test --release every_order; }
# Run the real code and check its log against the model. Prints the verdict of trace.sh.
real_run() { TRACE_LOG=$1 cargo test --features trace real_run > /dev/null 2>&1 && sh "$trace" "$spec" "$1"; }

cp -R Cargo.toml Cargo.lock src faults "$copy"
cd "$copy"
git apply faults/lock_per_step.patch
if every_order > "$copy/out" 2>&1; then fail "loom passes with the fault"; fi
grep -q 'no_lost_hit ... FAILED' "$copy/out" || { cat "$copy/out"; fail "loom fails with the fault, but not on no_lost_hit"; }
if real_run "$copy/log" > "$copy/out" 2>&1; then fail "the model follows a run with the fault"; fi
grep -q 'cannot take event 3' "$copy/out" || { cat "$copy/out"; fail "the trace check fails with the fault, but not at the second TakeLock"; }

cd "$here"
every_order > "$copy/out" 2>&1 || { cat "$copy/out"; fail "loom fails on the code"; }
real_run "$here/target/trace.log" || fail "the model does not follow a real run"
