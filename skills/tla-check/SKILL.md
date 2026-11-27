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

- Write each rule that the reader agrees to as an INVARIANT. If the model has no variable for a rule, add the variable. Never weaken a rule to make it hold. A rule that something eventually happens, such as "every job ends", is not about one state: write it as a PROPERTY, as described below.
- Write `Next` as a disjunction of named actions, so that each step of a counterexample carries the name of its action.
- TLC reports a state with no step out as a deadlock, also when it is a correct end state. Add to `Next` an action that is true only in the end states and changes nothing, such as `AllDone == (\A p \in Procs : pc[p] = "done") /\ UNCHANGED vars`.
- Keep the constants small. TLC explores every reachable state, so a model with no bound runs without end. Grow them in steps. One budget of calls for all threads grows more slowly than a budget for each thread.
- `SYMMETRY` over a set of threads that are all alike can cut the states of an invariant check by a large factor. It needs model values, such as `Threads = {t1, t2, t3}`, and a `Permutations` definition. A trace config then needs the same set as strings, so it is a config of its own.
- TLC's integers are 32-bit, from -2147483648 to 2147483647, and a larger number in the spec is an error. Model a wider number of the code, such as one that wraps at 2^32, with a small stand-in, and say why in the record.
- To say that a step never has to wait, use `ENABLED`, such as `reader = "close" => ENABLED Close`. A rule about the state alone cannot tell a step that waits from one that is about to happen, so it also fails for correct code.

## Read the result

| Exit code | Meaning |
|-----------|---------|
| 0 | Every rule holds in every reachable state, and each rule that something eventually happens holds in every run that the fairness allows. The last lines of the output give the count of distinct states. |
| 12 | An invariant breaks. The output names it and gives the shortest path. |
| 11 | Deadlock: a reachable state has no step out. |
| 13 | A temporal PROPERTY breaks. The output does not name it; see "Check that something eventually happens". |
| other | The spec or config has an error. Read the output from the top: the cause is often a few lines above the first `Error:` line. An exception of TLC after it generated states, or `Disk quota exceeded`, comes from the machine: TLC keeps its queue of states in the temp folder, and that reaches gigabytes at a few million states. Keep the output, give it a `TMPDIR` on a disk or smaller constants, and rerun before you change the spec. |

TLC stops at the first rule that breaks. To see whether another rule holds, copy the config to a scratch folder outside the repo, keep only that rule in the copy, and pass the copy as the second argument. Use one copy for each rule. Do not pass `-continue`: on a large model it prints millions of lines and still names only the first rule.

The script runs TLC with one worker for each core. With several workers, the path that TLC prints can be a little longer than the shortest one. Add `-workers 1` when you need the shortest, or `-workers N` to use fewer cores. Java gives TLC up to a quarter of the memory; to cap it, set `JAVA_TOOL_OPTIONS=-Xmx2g` or another size.

In a counterexample, `State 1` lists every variable. Each later state names the action that led to it and lists only the variables that changed, except the last state, which lists every variable again. For a model with large states, read the path first: `grep -E '^Error: Inv|^State [0-9]+: <'` gives the rule and the action of each step.

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

An action with `0:0` never ran, so no rule was tested against it. An action under `\E` over an empty set is missing from the list, so compare the list with `Next`. Read each `Warning:` line of the first run too: TLC warns when an action changes a variable that it also lists as UNCHANGED, and that action never runs. Either explain it, such as a fault switch that is off in this config, or fix the model. An action that changes nothing, such as `AllDone`, finds no new state but still shows how often it ran. So does an action that leads only to states that another action found first. An action under `\E` over a set that is a variable can show under the name of `Next`.

## Check that a fault still breaks its rule

A pass counts only if the check can fail. A model shows that with a switch for each deliberate fault: a `Faults` constant that is `{}` in the config. Switch one fault on, and require that one rule breaks:

```sh
sh <skill dir>/fault.sh SPEC.tla FAULT RULE [CONFIG.cfg] [extra TLC options]
```

The script checks a copy of the config with `Faults = {"FAULT"}` and with RULE as its only rule. For a fault that must break two rules, run it once for each.

| Exit code | Meaning |
|-----------|---------|
| 0 | The fault breaks the rule. |
| 1 | The rule holds with the fault on. The model can no longer fail there, so fix the model before you trust a pass. |
| 2 | The config has no `Faults = {}`, or it does not list the rule. |

## Check that something eventually happens

An invariant says that no state is bad. It cannot say that a job ends, a lock gets free, or a request gets a reply: a run that stops halfway breaks no invariant. Write such a rule with `~>` (leads to), and list it under `PROPERTY` in the config:

```tla
EveryJobEnds == \A j \in Jobs : Submitted(j) ~> Ended(j)
Fairness == \A w \in Workers : WF_vars(WorkerStep(w))
Spec == Init /\ [][Next]_vars /\ Fairness
```

- **The config needs `SPECIFICATION Spec`** in place of `INIT` and `NEXT`. With `INIT` and `NEXT` the model has no fairness, a run may stop at any point, and every such rule breaks at once.
- **Fairness is an assumption about what keeps running.** `WF_vars(A)` says that step `A` is taken at some point when it stays possible. Give it to the steps that the code takes without help: a thread that gets scheduled, a call that returns or raises. Give none to a step of the outside, such as a user who submits or a process that crashes. When a step can end in several ways, put the fairness on all the ways together, as in `WorkerStep(w)`, so that it does not force the good one. `SF_vars(A)` assumes more: `A` is taken when it is possible again and again, as with a fair lock. Use it only where the code gives that. Write each fairness assumption into the record in plain words, such as "every thread keeps getting scheduled, and every call of a job returns or raises".
- **A rule that the result stays** is a rule about steps: `EndedStays == [][\A j \in Jobs : Ended(j) => state'[j] = state[j]]_vars`. It goes under `PROPERTY` too, and a break of it gives exit 12.
- **Exit 13 does not name the rule,** and its path is not the shortest. It prints `Error: Temporal properties were violated.` To learn which rule broke, check each one in a config copy of its own. A path that ends in `Stuttering` is a run that stops there for good with the rule unmet. One that ends in `Back to state N` goes around that loop without end.
- **Show that it can fail.** `fault.sh` takes such a rule as it takes an invariant. A fault that drops a retry makes the run stop, and a fault that drops a counter makes it loop. For a rule that only the config with a fix lists, pass that config as the fourth argument.
- **When the code breaks the rule,** keep the rule as promised in a config of its own. The committed config can hold a second rule that names the cases that break, such as `Submitted(j) ~> (Ended(j) \/ Abandoned(j))`. Say in the record that this is what the code keeps and not what it promises, and list each named case as a known weakness.
- **A step that can come at any time and stops everything,** such as the exit of the process, breaks every such rule at once and hides the other breaks. Put it behind a constant, and check it in a config of its own.
- **A state where the run only waits needs a step too.** Workers that wait on an empty queue have no step out, and TLC reports that as a deadlock, exit 11, before it looks at the rule. Give each such state an action that changes nothing, as for the end states. Then a run that stops there shows as a break of the rule.
- **Limits.** TLC can miss a break of such a rule when the config has `SYMMETRY`, so leave it out. The check is much slower than for invariants: a model of 2,656 states took a second, and one of 238,086 states over two minutes. A trace check cannot show such a rule, because a log ends: make the test that writes the logs fail when a run does not settle. Leave such a rule out of the config of a trace check.

## Check that the model follows the real code

A model is tied to the code by hand. A trace check ties it by a real run: a test runs the code, the code logs each step, and TLC checks that the model can take the same steps in the same order. It catches a change that made the code leave the model, also in a run where no rule broke.

Have the code write one line each time it does something that the model has an action for, as a TLA+ record:

```
[action |-> "Write", thread |-> "t1", count |-> 1]
```

When you may not change the product code, log from the test: wrap or replace the parts that take the steps.

Log what the code does, at every place where it does it: a line at each place that takes the lock, not one line for each call. Then a change that takes the lock twice shows in every run. A log that is written to match the model hides that change in almost every run.

Write the line while the step still holds what makes it one indivisible step, such as the lock. If not, two threads can log in another order than they ran. Do not move a lock or hold it for longer to make room for the line, because that changes the code that you check. Log the values that the rules are about too, such as the count, and compare them in `Event`. A step that holds nothing, such as one atomic read, has no such moment. Then have the test run one thread at a time, with a stop at each step: the order of the lines is the order of the steps. A thread must not wait for a lock between two stops, or two threads run at once.

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

Keep the names `TraceLog`, `traceAt`, and `TraceUnfinished`: the script writes the first from the log and reads the other two. Its config has `INIT TraceInit`, `NEXT TraceNext`, the constants, and the rules of the model as INVARIANT. Leave `TraceUnfinished` out of the config, because the script adds it. Give a constant that the log names as strings, such as `Threads = {"t1", "t2"}`. For a step that the code cannot log, such as a lost reply, add `\/ LoseReply /\ UNCHANGED traceAt` to `TraceNext`. Keep such steps few, and log every step that the code can log: TLC tries an unlogged step at every point, also where the run did not take it, so a rule can break on a path that the run never took. Before you count such a break, replay its path against the code. The run must fit that config: the same ids, and no more work than the model allows, such as one hit for each thread. Start each run with an empty log, and write the logs outside the repo. For a step that the code logs and the model has no action for, such as a call that returns at once and changes nothing, add a line to `Event` with the guard of that case and `UNCHANGED` for the model's variables. Keep the guard: without it the line follows every log.

```sh
sh <skill dir>/trace.sh TRACESPEC.tla LOG [CONFIG.cfg]
```

`LOG` can be a folder. The script then checks every `.log` file under it, each distinct log once, and its last lines say how many logs there were, how many were distinct, and how often each step was logged. Many runs that all write the same log show one order only, so make the runs differ. A step with a low count is one that the runs rarely reach. It runs up to four TLCs at a time, each a JVM with a heap of its own; set `TLA_JOBS` to run more or fewer. The script reads subfolders too, so runs that need another config, such as other limits, go to a folder of their own that is not inside the first.

| Exit code | Meaning |
|-----------|---------|
| 0 | The model follows the whole log. |
| 1 | The model cannot take an event. The output gives that event and a state of the model before it. Either the code changed and the model must follow, or the code has a bug. |
| 12 | A rule of the model breaks on a path that follows the log so far. The output is TLC's, with the path. When the log has every step, that path is the run. With a step that the code cannot log, it can be a path that the rest of the log rules out. |
| 2 | The check did not run: a file is missing, the log is empty, the config lists `TraceUnfinished`, a `TraceLog.tla` sits next to the trace spec, or `TraceInit` allows no first state. The output says which. |

Show that the trace check can fail: delete one line from a log, or log a run of the code with a deliberate break, and see exit 1. An `Event` that allows too much follows every log. When the first run already fails, replay the event against the code before you change the trace spec: the code can be what is wrong.

A trace covers only the runs that the test made. It shows that those runs stay inside the model, and the model check shows that every run inside the model keeps the rules. Neither shows that the code never leaves the model in a run that no test made.

## Hand off

For each rule that breaks, give the rule, one plain sentence for what it protects, and the path as numbered steps in the reader's words, not as TLA+ action names. For a model of code, those are the code's words. Say what the model leaves out, and give the command that reruns the check.

When the model describes code, replay each bug path against the real code, as a test or a live repro, one step for each action. If the bug does not occur, treat the model as wrong until you show that it is not.
