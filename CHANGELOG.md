# Changelog

Each version is a git tag, such as `v0.5.2`. The GitHub Action is pinned by that tag.

## Unreleased

### Added

- `tla-check` says how to check that something eventually happens, such as "every job ends": the rule with `~>`, the config with `SPECIFICATION`, which steps get fairness, how to read exit 13, how to show that the check can fail, and what to do when the code breaks the rule. The create skill points to it. Before, the skills covered only rules about single states.
- An eval case, `eventually`, with a job queue where a job that times out never ends.

## 0.5.8 - 2026-11-26

### Fixed

- The steps for a rename in a record sent the reader straight to the sync, which refuses while a cited line has its old text. The create skill and both example records now say to give each cited line its new text first.
- The maintain skill commits its update only when the agent's instructions let it commit. In a test, an agent that was asked only to check made a branch and a commit.
- The maintain skill said that `drift.sh` names each cited line that is missing. It names the first one of a stretch.
- The eval grader `leaves-code-alone` also matched an edit of any file whose name ends in `counter.py`. It now matches the path of the file, and `ran-drift` no longer counts a read of the script as a run. The fixture of the two maintain cases takes out what the example's record says about files that the fixture repo does not have.

## 0.5.7 - 2026-11-26

### Added

- `python.md` says how to hold a thread between two plain statements with `sys.settrace`, and that free runs on CPython 3.12 to 3.14 did not switch there, so a test of such a bug must force the switch.

### Changed

- `trace.sh` runs up to four TLCs at a time on a folder of logs. Before, it ran one for each core, which used up the memory of a machine with 24 cores. `TLA_JOBS` sets another count.

### Fixed

- `tla-check` said that exit 12 of a trace check means that a rule breaks in the logged run. With a step that the code cannot log, the rule can break on a path that the run never took. It now says so, and says to log every step that the code can log.
- The maintain skill says which commit `drift.sh` takes as the last sync, and why its list can hold commits that were read already.

## 0.5.6 - 2026-11-26

### Added

- `report-finding`, a skill of its own for what happens before a finding goes to a project. The create skill held these steps, and they did not load when a user asked only to report a finding. It also says that a request to report a finding that names no route asks for the report, not for sending it.
- `evals/`, cases for `claude plugin eval` from earlier failures: a stale checkout, a security finding to report, a request for a public issue about one, and a rename and a removed lock in verified code. `evals/run.sh` runs them.
- The create skill reads the records that the repo has already. It skips a rule that one covers, adds a new path to the state of an existing model to that model, and ends with a ranked list of the other targets, each marked covered or not. An eval case, `find-more`, checks it.
- What to do when a path is added to a model, from a test that built one: check each old step against the new path, restate a rule that the path changes on purpose, put the fault of a step that is itself the break on top of its fix, and sync the record with the finding in a config of its own.
- The hand-off says that a config other than the one next to its spec needs a CI step of its own, and the test of the record requires that each finding can still be replayed after the refactor.

## 0.5.5 - 2026-11-25

### Added

- The create skill checks how far the checkout is behind the project, and asks whether to verify the checkout or the latest code.
- Before a finding is reported, the create skill replays it on the latest code and release, looks for other code that keeps the same rule, gives it a test of its own, keeps a security bug on the project's private route, and asks the user what to do with each report instead of sending it.

### Changed

- Cited text needs to be unique only among the later lines of its file. A step whose line repeats further down is covered by the hash of its stretch, with a line next to it cited.

## 0.5.4 - 2026-11-25

### Added

- `go.md`, a guide for Go, from a test on a real network router: a test that tries every order of the calls that it can stop at, paired with a model for the steps inside them, what `-race` and fuzzing cover, reading what a library call really does, test runs that print `ok` without checking anything, fault patches for a whole module, coverage of statement blocks, and a module that a check assumes.
- `trace.sh` takes `TLA_JOBS` to run fewer TLCs at a time on a folder of logs.
- `tla-check` says that TLC's integers are 32-bit, and how to give TLC fewer cores and less memory.

### Changed

- The text that a record cites for a line must be unique in its file, so that a changed line is reported as itself.
- The create skill says to keep a fix for a check of the real code as a patch, with the break of the rule made on top of it. Before, only `rust.md` said so.

## 0.5.3 - 2026-11-24

### Added

- `php.md`, a guide for PHP web apps, from a test on a real Laravel app: which check fits, what counts as one step when requests, jobs, and commands share a database, how to run several processes in one PHPUnit test and log a trace, how to race on PostgreSQL, and why `vendor/` must be copied and not linked.
- The create skill says to confirm that the deliberate break of the record test really breaks the property, when a read can be part of the next step, and where to show that the check of a broken rule can fail.
- `c-cpp.md`, a guide for C and C++, from a test on real C++ firmware: when CBMC fits and when it cannot read the code, how to make sanitizers stop a test on undefined behavior, inputs in blocks of their exact size, what AddressSanitizer cannot see, how to count what a test reached, and what to say when a test stands in for a proof.
- The record names the plugin and its version for `drift.sh` for every kind of check, and a pointer skill stays local also when the user's or the repo's rules say not to commit agent folders.
- The create skill says that a verifier that cannot read the code counts as one that does not finish, that coverage is the count of steps for a test, and that a hand-off which delivers a test for a proof says so first. The recipe for a fault patch moved there, and it now works for uncommitted changes.

### Changed

- "Cheap to rerun" asks for few commands, each named in the record, instead of one.

### Fixed

- `drift.sh --sync` piped into `head`, or run with its output closed, stopped before it wrote the records. It now prints its report only at the end.

## 0.5.2 - 2026-11-23

### Changed

- `rust.md` says why Kani does not finish on `format!`, and gives a stub for the capacity hint that makes it finish.
- More on Kani in `rust.md`, from a second run: which arguments of a harness to fix, how to check a returned string, the empty input, how out of memory and an unreached cover look in the output, how to get the input that breaks a rule, and that `--harness` matches by part of a name.

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
