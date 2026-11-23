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

The config defaults to the `.cfg` file next to the spec. The script needs Java 11 or later on `PATH`. The first run downloads the checksum-pinned TLC jar (1.7.4) into `~/.cache/tla-check` and needs the network. Set `TLA2TOOLS` to use your own jar and `JAVA` to use another java binary. The run leaves no files next to the spec; its scratch files go to the system temp folder, or to `TMPDIR` when that is set. TLC's banner prints its own internal version, `TLC2 Version 2.19`, for the 1.7.4 release; that is the right jar.

TLC needs the file name of a spec to match its module name. To check a changed copy of a spec, keep the file name and put the copy in another folder.

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
| other | The spec or config has an error. Read the output from the top: the cause is often a few lines above the first `Error:` line. |

TLC stops at the first rule that breaks. To see whether another rule holds, copy the config to a scratch folder outside the repo, keep only that rule in the copy, and pass the copy as the second argument. Use one copy for each rule. Do not pass `-continue`: on a large model it prints millions of lines and still names only the first rule.

The script runs TLC with one worker for each core. With several workers, the path that TLC prints can be a little longer than the shortest one. Add `-workers 1` when you need the shortest.

In a counterexample, `State 1` lists every variable. Each later state names the action that led to it and lists only the variables that changed, except the last state, which lists every variable again.

A pass covers the model within its constants. It says nothing about code that the model does not describe.

## Check that a pass is not empty

Rules hold in a model where the steps that matter never happen. After a pass, run again with `-coverage 1`, and keep the line for each action:

```sh
sh <skill dir>/check.sh SPEC.tla -coverage 1 | grep -E '^<.*>: [0-9]+:[0-9]+$'
```

The exit code of that command is the one from `grep`, not from TLC, so use it only after a run that passed. Each line names an action, then the count of new states that it found, then the count of times that it ran:

```
<TakeLock line 16, col 1 to line 16, col 11 of module Counter>: 15:15
<ReplyLost line 40, col 1 to line 40, col 9 of module Counter>: 0:0
<AllDone line 38, col 1 to line 38, col 7 of module Counter>: 0:6
```

An action with `0:0` never ran, so no rule was tested against it. Either explain it, such as a fault switch that is off in this config, or fix the model. An action that changes nothing, such as `AllDone`, finds no new state but still shows how often it ran.

## Hand off

For each rule that breaks, give the rule, one plain sentence for what it protects, and the path as numbered steps in the reader's words, not as TLA+ action names. For a model of code, those are the code's words. Say what the model leaves out, and give the command that reruns the check.

When the model describes code, replay each bug path against the real code, as a test or a live repro, one step for each action. If the bug does not occur, treat the model as wrong until you show that it is not.
