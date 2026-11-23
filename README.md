# formal-proofs

Skills for coding agents that formally verify the code where a bug costs the most, and keep that verification true to the code as it changes.

| Skill | What it does |
|-------|--------------|
| `create-formal-verification` | Finds the code where a bug costs the most and tests reach the least, verifies one property of it, and generates a project-local verify skill. |
| `maintain-formal-verification` | After merges and refactors, brings the verification back in line with the code and says whether each failure is drift or a real bug. Includes `drift.sh`, which lists changes to verified code since the last sync. |
| `tla-check` | Checks a TLA+ model with TLC from one shell script. Needs only Java; prints pass or fail and the shortest path to a break. |
| `statechart` | Checks a TLA+ model with TLC and draws it as a Mermaid statechart. Heavier: needs a TypeScript runtime and mise. |

The first three can be invoked by the agent when a task calls for them. `statechart` runs only when you ask for it.

## Install

### Claude Code

```
/plugin install formal-proofs --marketplace jaschadub/claude-skill-formal-proofs
```

On versions before 2.1.275, add the marketplace first:

```
/plugin marketplace add jaschadub/claude-skill-formal-proofs
/plugin install formal-proofs@formal-proofs
```

The skills are then available in every project as `/formal-proofs:create-formal-verification` and so on.

### Cursor

The repo carries a `.cursor-plugin/plugin.json`; add it as a plugin from this repository.

### Codex, Copilot CLI, Gemini CLI, and other agents

The skills are plain `SKILL.md` folders. Link them into the shared skills directory:

```sh
git clone https://github.com/jaschadub/claude-skill-formal-proofs.git
mkdir -p ~/.agents/skills
ln -s "$PWD"/claude-skill-formal-proofs/skills/* ~/.agents/skills/
```

## Requirements

- `tla-check`: Java 11 or later. The first run downloads the checksum-pinned TLC jar (1.7.4) into `~/.cache/tla-check`.
- `statechart`: Node 22.18+, Bun 1.1.5+, or Deno 2+. Its first run installs Java and TLC with [mise](https://mise.jdx.dev); set `TLA2TOOLS` and `JAVA` to use your own.
- `drift.sh`: git and a POSIX shell.

## Development

```sh
sh skills/tla-check/test.sh
shellcheck skills/tla-check/*.sh skills/maintain-formal-verification/drift.sh
claude plugin validate .
```

## Credits

`create-formal-verification`, `maintain-formal-verification`, and `statechart` are adapted from the `pstack` plugin in [cursor/plugins](https://github.com/cursor/plugins) at commit `7a58391` (MIT, © 2026 Lauren Tan). Each of those skill directories carries the original license. The upstream `statechart` test suite is not included. `tla-check` and `drift.sh` are new.

MIT © 2026 Jascha Wanger ([jascha.me](https://jascha.me))
