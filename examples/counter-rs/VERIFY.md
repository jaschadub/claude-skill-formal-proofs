# Verify the hit counter in Rust

`Counter::hit()` in `src/lib.rs` takes the lock, reads the count, and writes it back plus one. If the lock is freed between the read and the write, two threads can read the same count, and one hit is lost. The closest test, `one_hit_counts`, asserts that one hit on one thread is counted. It never runs two hits at the same moment.

This folder is a worked example of a record for Rust code. It shows two checks: one that runs the real code under every order of steps, and one that ties a TLA+ model to a real run. The CI of this repo runs both with `sh examples/counter-rs/test.sh`.

## Does your change touch it?

| Code | What the checks take from it | Model action |
|------|------------------------------|--------------|
| `self.count.lock()` | waits for the lock and takes it | `TakeLock` |
| `let seen = *count` | reads the shared count | `Read` |
| `*count = seen + 1`, then the guard `count` is dropped at the end of `hit` | writes the count and frees the lock | `Write` |

A change to the order of these lines, to where the guard is dropped, or a new writer of `count` needs the checks. So does a change to a `trace!` line, because the trace check reads what those lines log.

```
covered:
  - examples/counter-rs/src/lib.rs 26824ebac3bd
    > pub fn hit(&self)
    > self.count.lock()
    > let seen = *count
    > *count = seen + 1
    > trace!("Write"
```

`drift.sh` compares the hash above with the text from the first cited line to the last. It is in the `maintain-formal-verification` skill of the `formal-proofs` plugin. Run it from the repo root: `sh <that skill's folder>/drift.sh`.

## The rules

| Rule | What it promises | Harm if it breaks |
|------|------------------|-------------------|
| `no_lost_hit` (loom), `NoLostHit` (model) | Every finished hit is counted. | The counter shows fewer hits than happened. |
| The code stays inside the model. | Each step that a real run logs is a step that `examples/counter/Counter.tla` allows at that point, and it leaves the count that the model holds. | The model passes while it describes code that no longer exists. |

## Run the checks

Run these from `examples/counter-rs`. The tools come from the `formal-proofs` plugin, https://github.com/jaschadub/skill-formal-proofs. `trace.sh` needs version 0.3.0 or later.

1. **Every order, on the real code.** `RUSTFLAGS="--cfg loom" cargo test --release every_order`. [loom](https://docs.rs/loom) runs `no_lost_hit` once for each order in which two threads can take their steps. A pass is `test result: ok. 1 passed`. A run that reports 0 tests checked nothing: the `--cfg loom` flag was missing.
2. **A real run against the model.** `TRACE_LOG=$PWD/target/trace.log cargo test --features trace real_run` runs three real threads and writes one line for each step, with the count after it. Then check the log with `trace.sh` from the `tla-check` skill: `sh <that skill's folder>/trace.sh ../counter/CounterTrace.tla target/trace.log`. A pass is `ok: the model follows all 9 events`.

The model itself has its own record, `examples/counter/VERIFY.md`. Check 1 runs the real code, but only the calls that the test makes, and only through loom's types. A change that adds a writer of `count`, or a lock or an atomic from `std`, passes it unseen, so read the change against the table first.

## When a change touches the covered code

These steps are for your own change, and for a change that you review before it lands. For a change that landed without them, follow the `maintain-formal-verification` skill.

1. If the change alters nothing in the table above, such as a rename, confirm that by reading it, give each line that the table or the `covered:` block cites its new text, run both checks, and go to step 5.
2. Run check 2 first. If the model cannot take an event, the code left the model at that event. Decide which one is right. Update the model and `CounterTrace.tla` from the code when the change is intended, and follow the model's own record.
3. Run check 1. If `no_lost_hit` fails, some order of the two threads loses a hit. loom prints the assertion that failed and not the order, so find the order in the code: look for a place where the lock is free between the read and the write. That is a bug in the change: report it, do not weaken the test, and do not sync.
4. Run the fault below and see that both checks fail.
5. Only then run `drift.sh --sync examples/counter-rs/VERIFY.md` from the repo root, check the line numbers that it prints, and commit the record with the change.

## Faults that must break a check

A fault is a patch in `faults/`. Copy this folder, without `target`, to a scratch folder outside the repo, run `git apply faults/<name>.patch` there, and run both checks in that copy. A patch that no longer applies means that the covered code changed: make it again from the new code.

| Fault | The break in the code | What must fail |
|-------|-----------------------|----------------|
| `lock_per_step.patch` | `hit()` frees the lock after the read and takes it again for the write | Check 1: `no_lost_hit` fails with `left: 1, right: 2`. Check 2: the model cannot take event 3, the second `TakeLock` of one thread. |

Check 2 fails with this fault in every run, also in a run that loses no hit.

## Known weaknesses

None. The checks show no break of the design within their bounds.

## What the checks do not cover

- **Bounds:** loom runs two threads with one hit each. The model has three threads with one hit each.
- **Only what loom sees:** loom controls only its own types, here `loom::sync::Mutex`. Code that uses another lock or an atomic from `std` is outside the check.
- **The trace covers the runs that the test made.** It shows that those runs stay inside the model. It does not show that every run does.
- **Other processes:** the lock is in memory, so two processes that share a stored count are out of scope.
