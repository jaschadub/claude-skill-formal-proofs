#!/bin/sh
# Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
# After an edit to verified code that no longer matches its VERIFY.md record, tell the agent.
# usage: sh remind.sh < HOOK.json    a hook of Claude Code or Codex: JSON in, JSON out
#        sh remind.sh FILE...        any other agent, such as Pi: prints the reminder as plain text
# It prints nothing when no edited file is covered code, or when the covered code still matches.
plugin=$(cd "$(dirname "$0")/.." && pwd) || exit 0
drift=$plugin/skills/maintain-formal-verification/drift.sh
event=
if [ $# -gt 0 ]; then
  files=$(printf '%s\n' "$@")
else
  input=$(cat)
  field() { printf '%s' "$input" | sed -n "s/.*\"$1\" *: *\"\([^\"]*\)\".*/\1/p" | head -n 1; }
  event=$(field hook_event_name)
  cwd=$(field cwd)
  [ -z "$cwd" ] || cd "$cwd" 2>/dev/null || exit 0
  # The edited files: "file_path" (Claude Code), "path", or the file lines of a Codex patch.
  files=$(printf '%s' "$input" | grep -oE '"(file_path|path)" *: *"[^"]*"|\*\*\* (Add|Update|Delete) File: [^\\"]*' |
    sed 's/^"[a-z_]*" *: *"//; s/"$//; s/^\*\*\* [A-Za-z]* File: //')
fi

# Print the line of the drift report for file $1, when a record covers it and it no longer matches.
report() (
  cd "$(dirname "$1")" 2>/dev/null || exit 0
  prefix=$(git rev-parse --show-prefix 2>/dev/null) || exit 0
  cd "$(git rev-parse --show-toplevel)" || exit 0
  path=$prefix$(basename "$1")
  # Only the records that name this file, so that an edit to other code costs one search.
  records=$(git ls-files -co --exclude-standard -- ':(glob)**/VERIFY.md' | xargs grep -lF -- "$path" 2>/dev/null) || exit 0
  # shellcheck disable=SC2086 # drift.sh takes records with no space in their path
  sh "$drift" $records 2>/dev/null | grep -F ": $path: "
)
hits=$(printf '%s\n' "$files" | while IFS= read -r file; do [ -z "$file" ] || report "$file"; done | sort -u)
[ -n "$hits" ] || exit 0
records=$(printf '%s\n' "$hits" | sed 's/: .*//' | sort -u | tr '\n' ' ')
text="formal-proofs: this edit changed verified code, which no longer matches its record. $(printf '%s' "$hits" | tr '\n' ';' | sed 's/;/; /g'). Before you finish, follow that record: make the verification describe the change and run the check. Only then run, from the root of the repo: sh \"$drift\" --sync ${records% }"
if [ -z "$event" ]; then
  printf '%s\n' "$text"
else
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" \
    "$(printf '%s' "$text" | tr -d '[:cntrl:]' | sed 's/[\\"]/\\&/g')"
fi
