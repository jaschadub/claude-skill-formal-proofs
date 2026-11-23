#!/bin/sh
# Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
# PostToolUse hook for file edits. Reads the hook's JSON on stdin. When the edited file is verified
# code that no longer matches its VERIFY.md record, it tells the agent. Otherwise it prints nothing.
plugin=$(cd "$(dirname "$0")/.." && pwd) || exit 0
drift=$plugin/skills/maintain-formal-verification/drift.sh
file=$(sed -n 's/.*"file_path" *: *"\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$file" ] || exit 0
cd "$(dirname "$file")" 2>/dev/null || exit 0
prefix=$(git rev-parse --show-prefix 2>/dev/null) || exit 0
file=$prefix$(basename "$file")
cd "$(git rev-parse --show-toplevel)" || exit 0
hit=$(sh "$drift" 2>/dev/null | grep -F ": $file: " | head -n 1)
[ -n "$hit" ] || exit 0
rec=${hit%%: *}
text="formal-proofs: this edit changed verified code. $file no longer matches the record in $rec (${hit#*: *: }). Before you finish, follow that record: make the verification describe the change, run the check, and only then run: sh $drift --sync $rec"
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' \
  "$(printf '%s' "$text" | tr -d '[:cntrl:]' | sed 's/[\\"]/\\&/g')"
