# Catch bugs your tests miss

Your coding agent turns rules like “retrying a payment must never charge a customer twice” into formal checks you can rerun as the code changes.

| Skill | What it does |
|-------|--------------|
| `create-formal-verification` | Finds the code where a bug costs the most, checks one rule of it against every order of events, and writes a record (`VERIFY.md`) so that the next agent can recheck it. |
| `maintain-formal-verification` | After merges and refactors, brings the check back in line with the code, and says whether a failure is a real bug. |
| `tla-check` | Runs a TLA+ model, and checks a log of what the real code did against it. Needs only Java. |
| `statechart` | Runs a TLA+ model and draws it as a chart. Needs a TypeScript runtime and mise. |

A hook reminds the agent when it edits verified code, and a GitHub Action catches the same in CI.

For Rust code, the agent also gets a guide to the checkers that run the real code, such as loom, shuttle, and Kani.

See [how it works](docs/design.md), a [worked example](examples/counter), and [the same in Rust](examples/counter-rs).

## Install

**Claude Code**

```
/plugin marketplace add jaschadub/skill-formal-proofs
/plugin install formal-proofs@formal-proofs
```

**Codex**

```sh
codex plugin marketplace add jaschadub/skill-formal-proofs
codex plugin add formal-proofs@formal-proofs
```

**Pi**

```sh
pi install git:github.com/jaschadub/skill-formal-proofs
```

**Other agents:** the skills are plain `SKILL.md` folders. Clone the repo and link `skills/*` into `~/.agents/skills/`. Cursor can add the repo as a plugin.

## Use

Ask your agent in plain words:

- “Formally verify the token refresh code.”
- “Is the model still true to the code?”
- “Check a real run of the code against the model.”

## Check it in CI

```yaml
- uses: actions/checkout@v4
- uses: jaschadub/skill-formal-proofs@v0.3.0
  with:
    specs: formal/session/Session.tla
```

The build fails when verified code changed without a recheck, or when a model breaks a rule. A `traces` input also fails it when a model cannot follow the log of a real run. [`examples/github-workflow.yml`](examples/github-workflow.yml) is a full workflow to copy.

## Requirements

- Java 11 or later, and git. The first check downloads the TLA+ tools once.
- `statechart` only: Node 22.18+, Bun, or Deno, and [mise](https://mise.jdx.dev).

## Development

The tests need Java, Node 22.18 or later, and cargo.

```sh
sh skills/tla-check/test.sh
sh skills/maintain-formal-verification/test.sh
sh hooks/test.sh
sh examples/counter-rs/test.sh
cargo clippy --manifest-path examples/counter-rs/Cargo.toml --all-targets --features trace -- -D warnings
(cd skills/statechart/scripts && npm install --no-package-lock && npm test)
shellcheck hooks/*.sh skills/tla-check/*.sh skills/maintain-formal-verification/*.sh examples/counter-rs/*.sh
```

## Credits

`create-formal-verification`, `maintain-formal-verification`, and `statechart` are adapted from the `pstack` plugin in [cursor/plugins](https://github.com/cursor/plugins) at commit `7a58391` (MIT, © 2026 Lauren Tan). Each of those skill folders carries the original license. The chart fixes for warnings, actions that never ran, tool paths, and comments follow pull requests 1254, 1303, 1017, and 1222 there.

MIT © 2026 Jascha Wanger ([jascha.me](https://jascha.me))
