# claude-skill-formal-proofs

Claude Code skills for formally verifying code and keeping that verification true to the code as it changes.

| Skill | What it does |
|-------|--------------|
| `/create-formal-verification` | Finds the code where a bug costs the most and tests reach the least, verifies one property of it, and generates a project-local verify skill. |
| `/maintain-formal-verification` | After merges and refactors, brings the verification back in line with the code and says whether each failure is drift or a real bug. |
| `/tla-check` | Checks a TLA+ model with TLC from one shell script. Needs only Java; prints pass or fail and the shortest path to a break. |
| `/statechart` | Checks a TLA+ model with TLC and draws it as a Mermaid statechart, with the shortest path to each rule violation. |

All four are user-invoked only (`disable-model-invocation: true`).

## Install

```sh
git clone https://github.com/jaschadub/claude-skill-formal-proofs.git
ln -s "$PWD"/claude-skill-formal-proofs/skills/* ~/.claude/skills/
```

`/tla-check` needs Java 11+ and downloads the checksum-pinned TLC jar on first use.

`/statechart` needs Node 22.18+, Bun 1.1.5+, or Deno 2+. Its first run installs Java and TLC with [mise](https://mise.jdx.dev) and needs the network; set `TLA2TOOLS` and `JAVA` to use your own.

## Credits

Adapted from the `pstack` plugin in [cursor/plugins](https://github.com/cursor/plugins) (MIT, © 2026 Lauren Tan). Each skill directory carries the original license. The upstream `statechart` test suite is not included.
