# Catch bugs your tests miss

Your coding agent turns rules like “retrying a payment must never charge a customer twice” into formal checks you can rerun as the code changes.

| Skill | What it does |
|-------|--------------|
| `create-formal-verification` | Finds the code where a bug costs the most and tests reach the least, verifies one property of it, and writes a record (`VERIFY.md`) next to the verification that tells the next agent how to recheck it. |
| `maintain-formal-verification` | After merges and refactors, brings the verification back in line with the code and says whether each failure is drift or a real bug. Includes `drift.sh`, which reports verified code that changed since the last sync. |
| `tla-check` | Checks a TLA+ model with TLC from one shell script. Needs only Java; prints pass or fail and the shortest path to a break. |
| `statechart` | Checks a TLA+ model with TLC and draws it as a Mermaid statechart. Heavier: needs a TypeScript runtime and mise. |

The first three can be invoked by the agent when a task calls for them. `statechart` runs only when you ask for it.

[How it works](docs/design.md) shows the whole loop as a diagram.

## The record

The verification lives in the project as a committed file, `VERIFY.md`, next to the model. It holds the rules, the command, the faults, the limits, and the lines of code that the model depends on:

```
covered:
  - examples/counter/counter.py 49d00fd4737e
    > def hit():
    > with lock:
    > seen = count
    > count = seen + 1
```

Each `> ` line cites a line of the file by its text. The hash covers the text from the first cited line to the last. `drift.sh` stays quiet for an edit outside that stretch, reports an edit inside it, and names a cited line that is missing or moved. `drift.sh --sync` writes the new hash, and the agent runs it only after the model describes the changed code and the check passes.

[`examples/counter`](examples/counter) is a complete worked example: the code, the model, its config, and the record.

## Keep it checked

Three things make the check run without anyone remembering it.

**The hook, in the agent.** The install for Claude Code, Codex, and Pi sets it up. After the agent edits a file, the hook runs `drift.sh`. If the edit changed covered code, the agent gets this reminder, and nothing otherwise:

```
formal-proofs: this edit changed verified code, which no longer matches its record.
examples/counter/VERIFY.md: examples/counter/counter.py: cited line is missing or moved: with lock:.
Before you finish, follow that record: make the verification describe the change and run
the check. Only then run, from the root of the repo: sh .../drift.sh --sync examples/counter/VERIFY.md
```

**The GitHub Action, in CI.** It fails the build when covered code changed without a re-sync of its record, or when a model breaks a rule. Copy [`examples/github-workflow.yml`](examples/github-workflow.yml) into your project, or add the step to a job you have:

```yaml
- uses: actions/checkout@v4
- uses: jaschadub/skill-formal-proofs@v0.2.0
  with:
    specs: formal/session/Session.tla
```

This repo's own [CI](.github/workflows/ci.yml) runs the same step on the example.

**By hand, anywhere.** From the root of your project:

```sh
sh path/to/skills/maintain-formal-verification/drift.sh          # exit 1 when covered code changed
sh path/to/skills/tla-check/check.sh formal/session/Session.tla  # exit 12 when a rule breaks
```

## Install

### Claude Code

```
/plugin install formal-proofs --marketplace jaschadub/skill-formal-proofs
```

On versions before 2.1.275, add the marketplace first:

```
/plugin marketplace add jaschadub/skill-formal-proofs
/plugin install formal-proofs@formal-proofs
```

The skills are then available in every project as `/formal-proofs:create-formal-verification` and so on.

### Codex

```sh
codex plugin marketplace add jaschadub/skill-formal-proofs
codex plugin add formal-proofs@formal-proofs
```

Codex asks you to review the plugin's hook once, with `/hooks`, before it runs.

### Pi

```sh
pi install git:github.com/jaschadub/skill-formal-proofs
```

The skills are then available as `/skill:create-formal-verification` and so on.

### Cursor

The repo carries a `.cursor-plugin/plugin.json`; add it as a plugin from this repository. Cursor gets the skills, not the hook.

### Other agents

The skills are plain `SKILL.md` folders. Link them into the shared skills directory, which Copilot CLI, Gemini CLI, and others read:

```sh
git clone https://github.com/jaschadub/skill-formal-proofs.git
mkdir -p ~/.agents/skills
ln -s "$PWD"/skill-formal-proofs/skills/* ~/.agents/skills/
```

### What was tested

| Agent | Skills load | Hook fires |
|-------|-------------|------------|
| Claude Code 2.1 | yes | yes, in a live session |
| Codex | yes | not run live; the hook file follows the Codex hook format |
| Pi 1.6 | yes | the extension was run against a stand-in for Pi, not a live session |
| Cursor | not tested | no hook |

`sh hooks/test.sh` checks the hook script against the input format of each agent.

## Requirements

- `tla-check`: Java 11 or later. The first run downloads the checksum-pinned TLC jar (1.7.4) into `~/.cache/tla-check`.
- `statechart`: Node 22.18+, Bun 1.1.5+, or Deno 2+. Its first run installs Java and TLC with [mise](https://mise.jdx.dev); set `TLA2TOOLS` and `JAVA` to use your own.
- `drift.sh`: git and a POSIX shell.

## Development

```sh
sh skills/tla-check/test.sh
sh skills/maintain-formal-verification/test.sh
sh hooks/test.sh
shellcheck hooks/*.sh skills/tla-check/*.sh skills/maintain-formal-verification/*.sh
claude plugin validate .
```

The version is in five manifests, and CI checks that they agree.

## Credits

`create-formal-verification`, `maintain-formal-verification`, and `statechart` are adapted from the `pstack` plugin in [cursor/plugins](https://github.com/cursor/plugins) at commit `7a58391` (MIT, © 2026 Lauren Tan). Each of those skill directories carries the original license. The upstream `statechart` test suite is not included. `tla-check`, `drift.sh`, the `VERIFY.md` record, the hook, and the GitHub Action are new.

MIT © 2026 Jascha Wanger ([jascha.me](https://jascha.me))
