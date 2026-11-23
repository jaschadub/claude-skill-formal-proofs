# Rust targets

<!-- Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE. -->

Read this when the code to verify is Rust. It adds to `SKILL.md` and replaces none of it.

## Pick the checker

Each of these runs the real code, except the last. Say in the record and the hand-off what a pass of yours means, in the words of the third column.

| The question | Checker | What a pass means |
|--------------|---------|-------------------|
| Can threads in one process take their steps in a bad order? | [loom](https://docs.rs/loom) | Every order of the threads' steps. It sees only code that uses loom's types, so swap them in under `cfg(loom)`. It is exhaustive only without a preemption bound, so keep the test to two or three threads. For atomics it models the weak orderings in part: it can miss a bug that needs load buffering, and it can report a false alarm for `SeqCst`. |
| The same, in code that is too large for loom, or in async code on Tokio? | [shuttle](https://docs.rs/shuttle), with `shuttle-tokio` | `check_random` and `check_pct` try random orders. A pass is evidence and not a proof. `check_dfs` tries every order, and fits small tests only. Atomics behave as `SeqCst`. |
| Does a state machine keep its rules for every sequence of events? | A test that walks the real transition function through every reachable state, or [stateright](https://docs.rs/stateright) | Every reachable state, when the transitions are one pure function over an enum and the states are finite. With a depth limit, every sequence up to that depth. |
| Does a function hold for every input: no panic, no overflow, no index out of bounds, an invariant of a data structure? | [Kani](https://model-checking.github.io/kani/) | Every input, up to the unwind bound of each loop. It compiles concurrent code as if it ran on one thread, so it says nothing about the order of steps. |
| Must a function hold for input of every size, where the bound of Kani is not enough? | [Verus](https://github.com/verus-lang/verus), Creusot, or Prusti | A proof for every size. Each needs contracts written into the product code, and trusts its own description of `std`. Ask the user before you use one, and run the bounded check first. |
| Does `unsafe` code have undefined behavior? | Miri: `cargo +nightly miri test` | Only the runs that the tests make. It is not exhaustive. |
| Can processes, the disk, the network, a crash, or a timeout take steps in a bad order? | A TLA+ model with `tla-check`, tied to the code by a trace | Every order in the model. The trace shows that the runs of a test stay inside the model. |

A cargo test that is behind a `cfg` or a feature reports `0 passed` and exits 0 when the flag is missing. Put the full command in the record, and say what a pass prints.

loom needs four things: the dependency under `[target.'cfg(loom)'.dependencies]`, `check-cfg = ['cfg(loom)']` for the `unexpected_cfgs` lint in `Cargo.toml`, the body of the test inside `loom::model(|| { ... })`, and the command `RUSTFLAGS="--cfg loom" cargo test --release`. Put the other tests of the crate behind `not(loom)`, because loom's types panic outside `loom::model`. When a loom test fails, it prints the assertion that failed and not the order of steps, so work out the order from the code before you report it.

## Where a model of Rust code goes wrong

A step of the model must be one indivisible step of the code. In Rust these are the places where that fails. Check each against the code, and cite its line in the record.

- **Each `.await` ends a step.** Another task can run there. A step of the model must not span an `.await`, unless a lock is held across it. Then name the lock.
- **A future can stop at an `.await` and never go on.** `select!`, `timeout`, and an aborted or dropped task cancel it there, and the code after that `.await` does not run. For each `.await` inside one of those, give the model a step that stops there.
- **A guard is held for longer or shorter than it looks.** It is held until `drop(guard)` or the end of its scope. A guard that is not bound to a name, as in `let seen = *count.lock().unwrap();`, is freed at the end of that statement. In `match` and `if let` on a lock, the guard lives through the block that follows. Find where each guard is created and dropped, and model the lock for that stretch only.
- **`?` and a panic leave early.** The steps after them do not run, so a later save is skipped while an earlier one stays. A panic under a `std::sync::Mutex` poisons it, and the next `lock().unwrap()` panics too. Model each early exit that leaves state behind.
- **A lock on a file is not a mutex.** `File::lock` excludes other opens of the file, in this process or another, and ends when the handle is closed or dropped. loom and shuttle do not see it. Model it, and cover the helper that takes it.
- **`tokio::spawn` detaches.** The spawned task goes on after the function that spawned it returns or is cancelled. Model it as its own process.
- **A model assumes that each read sees the last write.** That holds for locks and for `SeqCst`. For `Relaxed`, `Acquire`, and `Release`, check the real code with loom, within the limits in the table above.

When the covered code is a `match` on a state enum, cite the arms, and say whether it has a `_ =>` arm. Without one, the compiler rejects a new state until someone handles it. With one, a new state passes without a word.

## Keep each fault as a patch

A check on the real code has no `Faults` constant. Keep each deliberate break as a patch in `faults/` next to the record, and list it with the test that must fail. Do not put a fault behind a cargo feature, because that ships the bug in the crate. A rule that the code breaks is not a fault: keep its test apart from the tests that pass, such as behind a feature of a harness crate, so that the committed check passes and the finding can be run again.

Make the patch with `git diff --relative` in the folder of the crate, or from the repo root when the harness sits in another crate than the covered code. To use one, copy the crate to a scratch folder outside the repo, without `target`, run `git apply` there, and run the check in the copy. Do not share a `target` folder between the copy and the crate: cargo can then run the binary of the other one, and a check passes or fails on code that it did not build. A patch that no longer applies means that the covered code changed, so make it again.

## Tie a model to the code with a trace

When the check is a model, add a trace check, as `tla-check` describes: a test runs the real code, the code logs each step, and TLC checks that the model can take the same steps. In Rust:

- Put the logging behind a cargo feature, such as `trace`, with a macro that expands to nothing without it.
- Log at every place where the code does a thing that the model has an action for, such as each `lock()`, and not once for each call.
- Log a step while it still holds the lock that makes it one step. A line that is logged after the lock is freed can land in the log after the next thread's line. When the guard has no name, as in `*count.lock().unwrap() = next;`, give it a name inside a block of its own that ends where that statement ended. A guard with a name in the outer scope is held to the end of that scope, and that hides the bug that the trace is there to find.
- Name who took the step with an id that the code already has, such as a client id or a thread name. Log the values that the rules are about.
- Let the test use real threads, tasks, or processes, with the ids and the amount of work that the trace config allows, and write a new log to a file that an environment variable names.

`examples/counter-rs` in the `formal-proofs` plugin, https://github.com/jaschadub/skill-formal-proofs, is a complete crate with a loom test, a fault patch, a trace, and its record.
