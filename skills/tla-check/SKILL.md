---
name: tla-check
description: "Use when a TLA+ spec must be run: to learn whether its invariants hold and to get the shortest counterexample, with only Java installed. Use the statechart skill instead only when a drawing of the state graph is wanted."
---

# TLA+ check

The lean way to run a TLA+ model. It answers one question: do the rules hold in every reachable state, and if not, what is the shortest path to the break. For a drawing of the state graph, use `statechart`.

## Run

```sh
sh <skill dir>/check.sh SPEC.tla [CONFIG.cfg] [extra TLC options]
```

The config defaults to the `.cfg` file next to the spec. The script needs Java 11 or later on `PATH`. The first run downloads the checksum-pinned TLC jar (1.7.4) into `~/.cache/tla-check` and needs the network. Set `TLA2TOOLS` to use your own jar and `JAVA` to use another java binary. The run leaves no files next to the spec. TLC's banner prints its own internal version, `TLC2 Version 2.19`, for the 1.7.4 release; that is the right jar.

## Write the spec

- Write each rule that the reader agrees to as an INVARIANT. If the model has no variable for a rule, add the variable. Never weaken a rule to make it hold.
- Write `Next` as a disjunction of named actions, so that each step of a counterexample carries the name of its action.
- TLC reports a state with no step out as a deadlock, also when it is a correct end state. Add to `Next` an action that is true only in the end states and changes nothing, such as `AllDone == (\A p \in Procs : pc[p] = "done") /\ UNCHANGED vars`.
- Keep the constants small. TLC explores every reachable state, so a model with no bound runs without end.

## Read the result

| Exit code | Meaning |
|-----------|---------|
| 0 | Every rule holds in every reachable state. The output ends with the count of distinct states. |
| 12 | An invariant breaks. The output names it and gives the shortest path. |
| 11 | Deadlock: a reachable state has no step out. |
| 13 | A temporal PROPERTY breaks. |
| other | The spec or config has an error. Read the first `Error:` line. |

TLC stops at the first rule that breaks. To see whether another rule holds, copy the config to a scratch folder outside the repo, keep only that rule in the copy, and pass the copy as the second argument. Use one copy for each rule. Do not pass `-continue`: on a large model it prints millions of lines and still names only the first rule.

In a counterexample, `State 1` lists every variable. Each later state names the action that led to it and lists only the variables that changed, except the last state, which lists every variable again.

A pass covers the model within its constants. It says nothing about code that the model does not describe.

## Hand off

For each rule that breaks, give the rule, one plain sentence for what it protects, and the path as numbered steps in the reader's words, not as TLA+ action names. Say what the model leaves out, and give the command that reruns the check.

When the model describes code, replay each bug path against the real code, as a test or a live repro, one step for each action. If the bug does not occur, treat the model as wrong until you show that it is not.
