---
name: tla-check
description: "Use when a TLA+ spec must be run: to learn whether its invariants hold and to get the shortest counterexample, to show that a deliberate fault still breaks its rule, or to check a log of what the real code did against the spec, with only Java installed. Use the statechart skill instead only when a drawing of the state graph is wanted."
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
- To say that a step never has to wait, use `ENABLED`, such as `reader = "close" => ENABLED Close`. A rule about the state alone cannot tell a step that waits from one that is about to happen, so it also fails for correct code.

## Read the result

| Exit code | Meaning |
|-----------|---------|
| 0 | Every rule holds in every reachable state. The last lines of the output give the count of distinct states. |
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

An action with `0:0` never ran, so no rule was tested against it. An action under `\E` over an empty set is missing from the list, so compare the list with `Next`. Read each `Warning:` line of the first run too: TLC warns when an action changes a variable that it also lists as UNCHANGED, and that action never runs. Either explain it, such as a fault switch that is off in this config, or fix the model. An action that changes nothing, such as `AllDone`, finds no new state but still shows how often it ran.

## Check that a fault still breaks its rule

A pass counts only if the check can fail. A model shows that with a switch for each deliberate fault: a `Faults` constant that is `{}` in the config. Switch one fault on, and require that one rule breaks:

```sh
sh <skill dir>/fault.sh SPEC.tla FAULT RULE [CONFIG.cfg]
```

The script checks a copy of the config with `Faults = {"FAULT"}` and with RULE as its only rule. For a fault that must break two rules, run it once for each.

| Exit code | Meaning |
|-----------|---------|
| 0 | The fault breaks the rule. |
| 1 | The rule holds with the fault on. The model can no longer fail there, so fix the model before you trust a pass. |
| 2 | The config has no `Faults = {}`, or it does not list the rule. |

## Check that the model follows the real code

A model is tied to the code by hand. A trace check ties it by a real run: a test runs the code, the code logs each step, and TLC checks that the model can take the same steps in the same order. It catches a change that made the code leave the model, also in a run where no rule broke.

Have the code write one line each time it does something that the model has an action for, as a TLA+ record:

```
[action |-> "Write", thread |-> "t1", count |-> 1]
```

When you may not change the product code, log from the test: wrap or replace the parts that take the steps.

Log what the code does, at every place where it does it: a line at each place that takes the lock, not one line for each call. Then a change that takes the lock twice shows in every run. A log that is written to match the model hides that change in almost every run.

Write the line while the step still holds what makes it one indivisible step, such as the lock. If not, two threads can log in another order than they ran. Do not move a lock or hold it for longer to make room for the line, because that changes the code that you check. Log the values that the rules are about too, such as the count, and compare them in `Event`.

Next to the model, write a trace spec that takes one event of the log at a time:

```tla
---- MODULE CounterTrace ----
EXTENDS Counter, Sequences, TraceLog
VARIABLE traceAt

Event(e) ==
  /\ \/ e.action = "TakeLock" /\ TakeLock(e.thread)
     \/ e.action = "Read" /\ Read(e.thread)
     \/ e.action = "Write" /\ Write(e.thread)
  /\ count' = e.count

TraceInit == Init /\ traceAt = 0
TraceNext == traceAt < Len(TraceLog) /\ Event(TraceLog[traceAt + 1]) /\ traceAt' = traceAt + 1
TraceUnfinished == traceAt < Len(TraceLog)
====
```

Keep the names `TraceLog`, `traceAt`, and `TraceUnfinished`: the script writes the first from the log and reads the other two. Its config has `INIT TraceInit`, `NEXT TraceNext`, the constants, and the rules of the model as INVARIANT. Leave `TraceUnfinished` out of the config, because the script adds it. Give a constant that the log names as strings, such as `Threads = {"t1", "t2"}`. For a step that the code cannot log, such as a lost reply, add `\/ LoseReply /\ UNCHANGED traceAt` to `TraceNext`. The run must fit that config: the same ids, and no more work than the model allows, such as one hit for each thread. Start each run with an empty log.

```sh
sh <skill dir>/trace.sh TRACESPEC.tla LOG [CONFIG.cfg]
```

`LOG` can be a folder. The script then checks every `.log` file under it, each distinct log once, and its last lines say how many logs there were, how many were distinct, and how often each step was logged. Many runs that all write the same log show one order only, so make the runs differ. A step with a low count is one that the runs rarely reach.

| Exit code | Meaning |
|-----------|---------|
| 0 | The model follows the whole log. |
| 1 | The model cannot take an event. The output gives that event and a state of the model before it. Either the code changed and the model must follow, or the code has a bug. |
| 12 | A rule of the model breaks in the run that the log describes. The output is TLC's, with the path. |
| 2 | The check did not run: a file is missing, the log is empty, the config lists `TraceUnfinished`, a `TraceLog.tla` sits next to the trace spec, or `TraceInit` allows no first state. The output says which. |

Show that the trace check can fail: delete one line from a log, or log a run of the code with a deliberate break, and see exit 1. An `Event` that allows too much follows every log. When the first run already fails, replay the event against the code before you change the trace spec: the code can be what is wrong.

A trace covers only the runs that the test made. It shows that those runs stay inside the model, and the model check shows that every run inside the model keeps the rules. Neither shows that the code never leaves the model in a run that no test made.

## Hand off

For each rule that breaks, give the rule, one plain sentence for what it protects, and the path as numbered steps in the reader's words, not as TLA+ action names. For a model of code, those are the code's words. Say what the model leaves out, and give the command that reruns the check.

When the model describes code, replay each bug path against the real code, as a test or a live repro, one step for each action. If the bug does not occur, treat the model as wrong until you show that it is not.
