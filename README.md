<p align="center">
  <img src="docs/logo.png" alt="Formal Proofs logo: a tuxedo with a bow tie" width="200">
</p>

<h1 align="center">Skill: Formal Proofs</h1>

<p align="center"><strong>Catch bugs your tests miss.</strong></p>

<p align="center">
  <a href="https://github.com/jaschadub/skill-formal-proofs/actions/workflows/ci.yml"><img src="https://github.com/jaschadub/skill-formal-proofs/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/jaschadub/skill-formal-proofs/tags"><img src="https://img.shields.io/github/v/tag/jaschadub/skill-formal-proofs?label=version" alt="Latest version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#claude-code"><img src="https://img.shields.io/badge/Claude_Code-plugin-black" alt="Claude Code plugin"></a>
  <a href="#codex"><img src="https://img.shields.io/badge/Codex-plugin-black" alt="Codex plugin"></a>
  <a href="#cursor"><img src="https://img.shields.io/badge/Cursor-plugin-black" alt="Cursor plugin"></a>
  <a href="#pi"><img src="https://img.shields.io/badge/Pi-package-black" alt="Pi package"></a>
  <a href="#other-agents"><img src="https://img.shields.io/badge/Other_agents-SKILL.md-black" alt="Other agents: SKILL.md folders"></a>
  <a href="#check-it-in-ci"><img src="https://img.shields.io/badge/GitHub_Action-CI_check-black" alt="GitHub Action: CI check"></a>
</p>

Your coding agent turns rules like “retrying a payment must never charge a customer twice” into formal checks you can rerun as the code changes.

| Skill | What it does |
|-------|--------------|
| `create-formal-verification` | Finds the code where a bug costs the most, checks one rule of it against every order of events, and writes a record (`VERIFY.md`) so that the next agent can recheck it. |
| `maintain-formal-verification` | After merges and refactors, brings the check back in line with the code, and says whether a failure is a real bug. |
| `report-finding` | Before a finding of a formal check goes upstream, checks it on the latest code and against other code that keeps the rule, keeps a security bug on the project's private route, and asks before anything is sent. |
| `tla-check` | Runs a TLA+ model, and checks a log of what the real code did against it. Needs only Java. |
| `statechart` | Runs a TLA+ model and draws it as a chart. Needs Java and a TypeScript runtime. |

A hook reminds the agent when it edits verified code, and a GitHub Action catches the same in CI.

For Rust, Python, PHP, C or C++, and Go code, the agent also gets a guide: which checker answers which question, and where a model of code in that language goes wrong.

See [how it works](docs/design.md), a [worked example](examples/counter), [the same in Rust](examples/counter-rs), and the [changelog](CHANGELOG.md).

## Install

### Claude Code

```
/plugin marketplace add jaschadub/skill-formal-proofs
/plugin install formal-proofs@formal-proofs
```

### Codex

```sh
codex plugin marketplace add jaschadub/skill-formal-proofs
codex plugin add formal-proofs@formal-proofs
```

Then open `/hooks` in Codex and trust the plugin's hook. Codex does not run it until you do.

### Cursor

```sh
git clone https://github.com/jaschadub/skill-formal-proofs ~/.cursor/plugins/local/formal-proofs
```

Then restart Cursor, or run **Developer: Reload Window**. The plugin shows up under **Customize**. It brings the skills and the hook.

### Pi

```sh
pi install git:github.com/jaschadub/skill-formal-proofs
```

### Other agents

The skills are plain `SKILL.md` folders. Clone the repo and link `skills/*` into `~/.agents/skills/`.

## Use

Ask your agent in plain words:

- “Formally verify the token refresh code.”
- “Is the model still true to the code?”
- “Check a real run of the code against the model.”
- “Draw the model as a chart.”

## Check it in CI

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0 # so that a failure can list the commits since the last sync
- uses: jaschadub/skill-formal-proofs@v0.5.7
  with:
    specs: formal/session/Session.tla
```

The build fails when verified code changed without a recheck, or when a model breaks a rule. A `traces` input also fails it when a model cannot follow the log of a real run, and a `faults` input when a deliberate fault no longer breaks its rule. [`examples/github-workflow.yml`](examples/github-workflow.yml) is a full workflow to copy.

## Requirements

- Java 11 or later, and git. The first check downloads the TLA+ tools once.
- `statechart` only: Node 22.18+, Bun, or Deno. Without Java on `PATH`, it also needs [mise](https://mise.jdx.dev).

## Development

The tests need Java, Node 22.18 or later, and cargo.

```sh
sh skills/tla-check/test.sh
sh skills/maintain-formal-verification/test.sh
sh hooks/test.sh
node --test pi/remind.test.ts
sh examples/counter-rs/test.sh
cargo clippy --manifest-path examples/counter-rs/Cargo.toml --all-targets --features trace -- -D warnings
(cd skills/statechart/scripts && npm install --no-package-lock && npm test)
shellcheck hooks/*.sh skills/tla-check/*.sh skills/maintain-formal-verification/*.sh examples/counter-rs/*.sh evals/*.sh evals/*/*.sh
```

`sh evals/run.sh` runs the agent evals with `claude plugin eval`: each case runs an agent with and without the plugin, and costs tokens. The runner refuses cases that give the agent a shell when a credentials file, such as an AWS config with a `credential_process`, points outside what its sandbox can exclude. There, `EVAL_TOOLS="Write Edit" sh evals/run.sh --case report-finding` runs a case without one.

## Credits

`create-formal-verification`, `maintain-formal-verification`, and `statechart` are adapted from the `pstack` plugin in [cursor/plugins](https://github.com/cursor/plugins) at commit `7a58391` (MIT, © 2026 Lauren Tan). Each of those skill folders carries the original license. The chart fixes for warnings, actions that never ran, tool paths, and comments follow pull requests 1254, 1303, 1017, and 1222 there.

MIT © 2026 Jascha Wanger ([jascha.me](https://jascha.me))
