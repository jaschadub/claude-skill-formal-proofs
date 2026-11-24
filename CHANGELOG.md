# Changelog

Each version is a git tag, such as `v0.5.1`. The GitHub Action is pinned by that tag.

## 0.5.1 - 2026-11-23

### Added

- `rust.md` says how to use Kani on real code, from a run on two string functions: where the harness goes, the command and what a pass prints, why each harness needs an input of one exact size, how to make a symbolic string, that `format!` may not finish, and that a run out of memory looks like a broken rule.
- The create skill says what to do when a verifier finishes only for small inputs or for part of the code, and when the code keeps a rule only because its callers meet a condition.

### Changed

- Fault patches are made with fixed `a/` and `b/` prefixes, so that they are the same under every git config. A fix that shows that a broken rule can hold is kept as a patch too.
- The hand-off says that the GitHub Action runs the TLA+ checks, and that another kind of check needs a CI step of its own.

## 0.5.0 - 2026-11-23

### Added

- `trace.sh` takes a folder of logs. It checks each distinct log once, several at a time, and says how many logs were distinct and how often each step was logged. The `traces` input of the action takes a folder too.
- The hand-off of `create-formal-verification` gives each rule in one plain sentence and asks the user whether it is the right rule.
- What to do when a property must hold at every size: run the bounded check on the real code first, say that it is not a proof, and offer a proof as a step that needs the user's consent. `rust.md` names the provers and what they cost.
- This changelog. CI checks that it has an entry for the version in the manifests.

## 0.4.1 - 2026-11-23

### Added

- `python.md`, a guide for Python code that uses threads: which check fits, what counts as one step, and how to log a trace from the test.
- Lessons from a test on real Python code, in the skills: show that a rule which the code breaks holds on a fixed variant, keep that rule in a config of its own, trust an unknown checker only after it catches a seeded fault, apply a fault patch in a scratch copy, and use `ENABLED` to say that a step never waits.

## 0.4.0 - 2026-11-23

### Added

- `fault.sh` in `tla-check`: it switches one deliberate fault on and requires that a named rule breaks. The action has a `faults` input for it.
- A hook for Cursor, `hooks/cursor.json`. It reminds the agent after an edit or a delete of verified code.

### Changed

- `statechart` uses the Java on `PATH` and the jar that `tla-check` keeps. It needs mise only when one of them is missing.
- The agent can start `statechart` without a command from the user.

## 0.3.1 - 2026-11-23

### Fixed

- `drift.sh` dropped the entries after a blank line or another indent in a `covered:` block, and still reported the record as synced. It now reads them, reports a block that names no file, gives a checkout with CRLF line ends the same hash, and says so when it is not run from the repo root.
- `trace.sh` refuses a `TraceLog.tla` next to the trace spec, which TLC read in place of the log. It skips lines of only spaces, names a trace spec with no first state, and exits with 2 for a missing file.
- `check.sh` downloads the jar to a file of its own for each run, and names a missing spec or config.
- The hook reminds after a Codex patch that deletes verified code, checks only the records that name the edited file, and quotes the path of the script.

### Changed

- The Rust example logs the count at each step, and its trace spec compares it.
- The README has an install section for each agent, and says that Codex runs the hook only after it is trusted in `/hooks`.

## 0.3.0 - 2026-11-23

### Added

- `trace.sh` in `tla-check`: it checks a log of what the real code did against the model. The action has a `traces` input for it.
- `rust.md`, a guide for Rust code, and `examples/counter-rs`, with a loom test, a fault patch, a trace, and its record.
- The chart report lists the warnings of TLC and the actions that never ran, above the rules that hold.
- `create-formal-verification` names the closest test, what it asserts, and the case that it does not reach.

### Fixed

- A relative `TLA2TOOLS` or `JAVA` path works in `check.sh` and in `statechart`.
- The chart parser no longer loses a variable after a comment that holds `<<1, 2>>`.
- The tests of the chart scripts run. Before, `npm test` passed with no test.

## 0.2.0 - 2026-11-22

First tagged version.

- Four skills: `create-formal-verification`, `maintain-formal-verification`, `tla-check`, and `statechart`.
- The `VERIFY.md` record, with `drift.sh` to report a change to the code that it covers.
- A hook that reminds the agent after an edit to verified code, and a GitHub Action for the same check in CI.
- Installs for Claude Code, Codex, and Pi, and a worked example in `examples/counter`.
