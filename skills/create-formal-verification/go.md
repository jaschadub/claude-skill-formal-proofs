# Go targets

<!-- Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE. -->

Read this when the code to verify is Go. It adds to `SKILL.md` and replaces none of it.

## Pick the checker

| The question | Checker | What a pass means |
|--------------|---------|-------------------|
| Can goroutines take their steps in a bad order? | A test of the real code that tries every order of the calls it can stop at (below), and a TLA+ model with `tla-check` for the steps inside those calls, tied by a trace from the same test | The test covers every order of whole calls at its stops, for the goroutines in the test. The model covers every order in the model. |
| Is there a data race? | `go test -race` | Only the runs that the tests make. The race detector sees memory that two goroutines touch without a lock, not a bad order of locked calls. |
| Does a function hold for every input? | Go's fuzzing, `go test -fuzz`, on the real code | Only the inputs that the fuzzer made. It is not a proof: say so. A proof needs a verifier such as Gobra, and the code annotated for it, which needs the user's consent. |

No mainstream Go tool runs the real code under every order of steps, as loom does for Rust. Say so when the user asked for a formal verification.

## Try every order in a test

- **Stop the goroutines where the code calls through an interface.** An embedded interface, a field of an interface type, or a dependency that the code takes can be replaced in a test by a wrapper that logs the call and waits until the test lets that goroutine go. A call on a concrete type, such as a method of a map type, cannot be stopped, so it runs whole between two stops. Write down which steps run together, and let the model cover the orders inside them.
- **Search the orders.** Run the code from a fresh state for each order. At each point, choose which waiting goroutine goes next, depth first, skip a state that an earlier run already reached, and check the rules in every state. Count the runs and the distinct states, and assert in the test that each kind of step ran.
- **Wait for every goroutine before you choose.** A goroutine that the code starts with `go f()` reaches its first stop later. Before each choice, wait until each goroutine is at a stop or done, or the same choices take other steps on a replay. Check that a replay of one order takes the same steps, and fail the test when it does not.
- **Never stop a goroutine while it holds a lock,** such as in a callback that a library runs under its own lock. Another goroutine then waits for that lock and never reaches its stop, and the search hangs. Let such a call run whole, and say so.
- **Run the search with `-race` too.** It is slower, and it adds the races of the runs that the search makes.
- **Log from the wrappers.** The search runs one goroutine at a time, so the order of the lines is the order of the steps, also for a line written outside the code's lock. Each distinct log costs one TLC run, so when the search makes thousands of runs, log a sample, such as every 500th run, and state it in the record.
- A test that must reach unexported fields sits in the package's own folder, in the same package. When it needs the state of a second package, read that state through its exported calls, or with `reflect` while every goroutine is stopped. The record can stay with the model in a folder of its own, and name the test by its path.

## Where a model of Go code goes wrong

- **One step is one locked call, one channel operation, or one atomic operation.** A call to a concurrent map that holds its lock is one step. Two calls are two steps, also when the second depends on the first, as in a check and then an insert.
- **A goroutine started with `go f()` runs later.** A callback that the code starts that way has not run when the call that started it returns.
- **Read the code of each library call that a rule depends on,** in the module cache (`go env GOMODCACHE`), and model what it does, not what its name says. Go cannot compare two func values, so a library that removes a callback by its value compares code pointers, with `reflect.ValueOf(f).Pointer()`. Every closure of one func literal has the same code pointer, so such a call can remove the callback of another caller.

## Test runs that can lie

- **A skipped test and a `-run` pattern that matches no test both print `ok` and exit 0.** Anchor the pattern, as in `-run 'TestName$'`, run with `-v`, and have the test print its count of runs. The record names what a pass prints.
- **Run with `-count=1`,** so that a pass is a run and not a cached result.
- **Keep a test of a rule that the code breaks out of the default run** with an environment variable that the test reads, such as `FINDINGS=1`, and `t.Skip` when it is not set. A build tag would also hide the file from `go vet`.

## Faults, coverage, and the record

- **A fault patch needs the whole module.** A package does not build alone. Copy every file that git tracks or would track, `git ls-files -co --exclude-standard`, to a scratch folder, and make the patch from the repo root. The build cache makes the copy fast to build.
- **Go counts statement blocks, not branches.** Run `go test -coverprofile=cover.out -coverpkg=PKG` and `go tool cover -func=cover.out`, then read each block that never ran in `go tool cover -html=cover.out`. Give each one an input or a reason in the record.
- **Code that a check assumes can sit in a module.** `drift.sh` cannot read the module cache, so cite the module's line in `go.mod`, such as `github.com/kataras/go-events v0.0.3`, in the `covered:` block. A new version then shows as a change. Write in the record what the check assumes that the module does.
- Name the Go version, the versions of the modules that the check assumes, and whether the run used `-race`.
