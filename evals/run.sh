#!/bin/sh
# Runs the eval suite with `claude plugin eval` on a copy of the files that git tracks or would
# add: build output such as cargo's target/ holds hard links, which the runner refuses.
# The cases build their fixtures with scaffold scripts, and the agent needs a shell.
# Extra options go to the runner, such as --case stale-checkout or --runs 1. EVAL_TOOLS sets the
# tools that the agent gets, such as "Write Edit" where the runner refuses Bash.
set -eu
cd "$(dirname "$0")/.."
copy=$(mktemp -d)
trap 'rm -rf "$copy"' EXIT
git ls-files -co --exclude-standard -z | xargs -0 cp --parents -t "$copy"
out=$PWD/evals/results/$(date -u +%Y-%m-%dT%H-%M-%S)
# shellcheck disable=SC2086 # EVAL_TOOLS is a list of tool names
claude plugin eval "$copy" --scaffold --trust-plugin --no-publish --judge-model sonnet --allow-tools ${EVAL_TOOLS:-Bash Write Edit} \
  --output-dir "$out" --report "$out/report.html" "$@"
