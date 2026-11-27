# Verify the hit counter

`hit()` in `counter.py` reads the count and writes it back plus one. Two threads that do this at the same moment can both read the same count, and one hit is lost. The example has no test. A test that calls `hit()` from several threads would assert the final count, and it would rarely meet that timing. The TLA+ model in `Counter.tla` checks every order of steps for three threads.

This folder is a worked example of the record that `create-formal-verification` leaves in a project. The CI of this repo checks it with the action in `action.yml`.

`CounterTrace.tla` lets the `tla-check` skill check a log of a real run against this model. `examples/counter-rs` writes such a log from the same counter in Rust.

## Does your change touch it?

| Code | What the model takes from it | Model action |
|------|------------------------------|--------------|
| `with lock:` | waits for the lock and takes it | `TakeLock` |
| `seen = count` | reads the shared count | `Read` |
| `count = seen + 1`, end of the `with` block | writes the count and frees the lock | `Write` |

A change to the order of these lines, to what the lock covers, or a new writer of `count` needs the check. A change to the `__main__` block does not.

```
covered:
  - examples/counter/counter.py 49d00fd4737e
    > def hit():
    > with lock:
    > seen = count
    > count = seen + 1
```

`drift.sh` compares the hash above with the text from the first cited line to the last. It reports a change between those lines and names a cited line that is missing or moved. It is in the `maintain-formal-verification` skill of the `formal-proofs` plugin. Run it from the repo root: `sh <that skill's folder>/drift.sh`.

## The rules

| Rule | What it promises | Harm if it breaks |
|------|------------------|-------------------|
| `NoLostHit` | Every finished hit is counted. | The counter shows fewer hits than happened. |
| no deadlock | TLC's built-in check: no reachable state is stuck with a thread waiting. | A request hangs. |

## Run the check

Check `examples/counter/Counter.tla` with the `tla-check` skill from the `formal-proofs` plugin, version 0.2.0 or later, https://github.com/jaschadub/skill-formal-proofs. The config `Counter.cfg` sits next to it. A run takes about a second and finds 46 distinct states. Every rule must hold with `Faults = {}`, and every action must run: `tla-check` says how to list the count for each action.

A pass on a model that no one updated says nothing about a change to the code. Update the model first.

## When a change touches the covered code

These steps are for your own change, and for a change that you review before it lands. For a change that landed without them, follow the `maintain-formal-verification` skill.

1. If the change alters nothing that the model describes, such as a rename, confirm that by reading it against the table above, give each line that the table or the `covered:` block cites its new text, and go to step 6.
2. Change the model so that it describes the new code, step for step. Write this from the code before you run anything. Update the cited lines above when a step moved or changed. When you add a step, a rule that names steps must name the new step too. That does not weaken the rule, as long as its sentence in the table stays true.
3. Run the check.
4. If a rule breaks, replay the path against `counter.py`, one step for each action. If a step cannot happen in the code, fix the model. If every step can happen, it is a bug in the change: report it, do not weaken the rule, and do not sync. Keep the updated model with the change, as a patch or on its branch.
5. If every rule holds, run the fault below and see that its rule breaks.
6. Only then run `drift.sh --sync examples/counter/VERIFY.md` from the repo root, check the line numbers that it prints, and commit the record with the change.

## Faults that must break a rule

Set the fault in a copy of the config in a scratch folder outside the repo, such as `Faults = {"no_lock"}`, and check the spec with that copy. From version 0.4.0, `tla-check` does this in one run for a fault and a rule.

| Fault | The break in the code | Rules that must break |
|-------|-----------------------|-----------------------|
| `no_lock` | `hit()` does not take the lock | `NoLostHit` |

## Known weaknesses

None. The model shows no break of the design within its bounds.

## What the check does not cover

- **Bounds:** three threads, one hit each.
- **Other processes:** the lock is in memory, so two processes that share a stored count are out of scope.
- **The link to the code is by hand.** The model does not read Python. It is true to the code only as long as this record is followed.
