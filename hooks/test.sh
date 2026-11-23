#!/bin/sh
# Self-check for remind.sh: quiet for an edit outside the cited lines, a reminder for one inside,
# in the input format of each agent.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir"
git init -q
mkdir sub
fail() { echo "FAIL: $*" >&2; exit 1; }
code() { printf 'header\nlock();\n%s\nfooter %s\n' "$1" "$2" > code.rs; }
# Claude Code: an absolute "file_path".
claude() { printf '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"%s/code.rs","old_string":"x"}}' "$dir" | sh "$here/remind.sh"; }
# Codex: a patch with a path from the working directory, which the hook gets as "cwd".
codex() { printf '{"hook_event_name":"PostToolUse","cwd":"%s","tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\\n*** %s File: code.rs\\n@@\\n-x\\n+y\\n*** End Patch"}}' "$dir" "${1:-Update}" | (cd sub && sh "$here/remind.sh"); }
# Pi and others: the file as an argument, plain text back.
plain() { sh "$here/remind.sh" "$dir/code.rs"; }

code 'say("hi");' 1
printf 'covered:\n  - code.rs\n    > lock(\n    > say("hi")\n' > VERIFY.md
sh "$here/../skills/maintain-formal-verification/drift.sh" --sync > /dev/null
code 'say("hi");' 2
[ -z "$(claude)$(codex)$(plain)" ] || fail "reminder for an edit outside the cited lines"

code 'say("hi"); log();' 2
want='formal-proofs: this edit changed verified code, which no longer matches its record. VERIFY.md: code.rs: changed (lines 2-3). Before you finish, .* --sync VERIFY.md'
claude | grep -q "^{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"$want\"}}\$" || fail "Claude Code"
codex | grep -q "^{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"$want\"}}\$" || fail "Codex"
plain | grep -q "^$want\$" || fail "plain text"
plain | grep -q 'sh "[^"]*/drift.sh" --sync VERIFY.md$' || fail "the path of drift.sh is not quoted in the reminder"

code 'log();' 2
claude | grep -qF 'cited line is missing or moved: say(\"hi\").' || fail "reminder is not escaped for JSON"
rm code.rs
codex Delete | grep -q 'code.rs: file is gone' || fail "no reminder when a Codex patch deletes covered code"
echo "ok"
