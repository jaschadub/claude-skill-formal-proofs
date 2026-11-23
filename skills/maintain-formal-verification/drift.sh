#!/bin/sh
# Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
# List changes to verified code since each verify skill's sync commit.
# usage: sh drift.sh [SKILL.md ...]    (default: .claude/skills/*/SKILL.md, from the repo root)
# Exit code: 0 every verify skill is in sync, 1 covered code changed, 2 no verify skill records coverage.
set -eu
[ $# -gt 0 ] || set -- .claude/skills/*/SKILL.md
status=2
for skill in "$@"; do
  [ -f "$skill" ] || continue
  sync=$(sed -n 's/^sync-commit: *\([0-9a-f]\{7,40\}\).*/\1/p' "$skill" | head -n 1)
  paths=$(awk '/^covered:/ { on = 1; next } on && /^  - / { print $2; next } on { on = 0 }' "$skill" | sort -u)
  [ -n "$sync" ] && [ -n "$paths" ] || continue
  [ "$status" = 1 ] || status=0
  # Paths are split on whitespace on purpose: one covered file per line, no spaces.
  # shellcheck disable=SC2086
  changes=$(git log --oneline "$sync..HEAD" -- $paths; git status --short -- $paths)
  if [ -n "$changes" ]; then
    status=1
    echo "$skill: covered code changed since $sync"
    echo "$changes" | sed 's/^/  /'
  else
    echo "$skill: in sync at $sync"
  fi
done
[ "$status" != 2 ] || echo "no verify skill with a sync-commit and covered block found" >&2
exit "$status"
