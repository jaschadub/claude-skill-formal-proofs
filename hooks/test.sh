#!/bin/sh
# Self-check for remind.sh: quiet for an edit outside the cited lines, a JSON reminder for one inside.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir"
git init -q
fail() { echo "FAIL: $*" >&2; exit 1; }
hook() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/code.rs","old_string":"x"}}' "$dir" | sh "$here/remind.sh"; }
code() { printf 'header\nlock();\n%s\nfooter %s\n' "$1" "$2" > code.rs; }

code 'say("hi");' 1
printf 'covered:\n  - code.rs\n    > lock(\n    > say("hi")\n' > VERIFY.md
sh "$here/../skills/maintain-formal-verification/drift.sh" --sync > /dev/null
code 'say("hi");' 2
[ -z "$(hook)" ] || fail "reminder for an edit outside the cited lines"
code 'say("hi"); log();' 2
hook | grep -q '^{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"formal-proofs: .*code.rs no longer matches the record in VERIFY.md (changed (lines 2-3))\..*"}}$' ||
  fail "no reminder for an edit inside the cited lines"
code 'log();' 2
hook | grep -qF '(cited line is missing or moved: say(\"hi\")).' || fail "reminder is not escaped for JSON"
echo "ok"
