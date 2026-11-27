# Messages, crashes, and several processes

<!-- Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE. -->

Read this when the promise spans several processes: a queue between them, a database or a folder that they share, a time limit after which work is offered again, or a promise that holds "also when a process crashes". It adds to `SKILL.md` and to the guide of the language, and replaces none of them. It comes from a test on an order service with a queue of files, a database, and worker processes, where the model found seven breaks of "charged exactly once" and each was replayed with real processes.

No tool runs several real processes under every order of their steps and every crash. So write a TLA+ model, check it with `tla-check`, and tie it to the code with a harness that runs the real processes one step at a time (below). Say first that this is a model check within its bounds.

## What one step is

- **One step is one system call on what the processes share, or one statement on the database** when each statement is a transaction of its own. A transaction is one step. Read how the code opens its connection: with autocommit, two statements are two steps, and a crash can come between them.
- **A crash can come between any two steps.** A charge and the mark that it is done, as two statements, are the usual break of "exactly once".
- **Find out by trial what each call does,** and write the result into the record. In the test run:
  - a rename is the atomic claim, and the loser gets an error;
  - a rename onto the same name never fails, so it claims nothing;
  - a rename keeps the file's time of change, so a time limit that is measured by it starts at the write, not at the take.
- **A process acts on a snapshot.** After a listing of a folder or a `SELECT`, the names and rows can be gone or changed. Keep the snapshot as state of the process, and make each later use a step of its own that can find the item gone.
- A read or a write that no other process can see, such as a temp file with a random name, can be part of the next step. Say where you do it.

## Messages

- Give each message a state, such as none, written, queued, taken, gone, and a step for each change.
- **Model what the queue does on its own.** A queue of files loses nothing and offers a message again after the time limit. A broker can also deliver twice and out of order: give the model a step for each, and say which you left out. Not tested here with a real broker.
- **Count what the rule is about,** such as the charges of each order. The code often stores only a sum, so the model needs a variable that the code does not have. In the harness, make the count readable, such as with one account for each order.
- **Split "exactly once" when it breaks:** at most once is an invariant, at least once for a message that reached the queue is a rule that something eventually happens, and "stored implies queued" is a third. Report which the code keeps.

## Time limits without a clock

- Give each message one flag for "its time is over", and a step that sets it at any time. The steps of the code that reset the time clear the flag.
- Add a constant that says in which cases the flag may be set: while the message waits, while a live worker holds it, while a dead worker holds it. Each case is a separate question. Two of the seven breaks needed no crash: a message that waited longer than the limit, and a worker that was slower than the limit.
- For a rule that something eventually happens, give the step that sets the flag weak fairness: time passes.
- In the harness, make a file old by setting its time back. Do not wait.

## Crashes

- **A crash is a step that is possible wherever the next step of the process is in a constant,** such as `CrashAt`. With every step in it, a crash can come anywhere. With one step in it, the path to one finding stands alone.
- **A crash loses the memory of the process, and nothing else.** Rows and files stay, also the half-done ones, such as a temp file or a claimed message. A model that cleans them up at the crash hides the finding.
- **Keep "killed" apart from "ended by its own error",** and write a rule for it, such as "no worker ends on an error that it did not catch". A worker that ends on an error that it did not catch is a finding with no kill at all. Two of the seven breaks were of this kind.
- **A process that only waits needs a step,** as `tla-check` says for a rule that something eventually happens: a loop that sleeps and looks again is a step that changes nothing. In the harness, replace the sleep.
- **The restart is a step behind a constant.** Say in the record who restarts a process: the code, or a supervisor that the repo does not hold. A rule that something eventually happens rests on that.
- **Give a crash no fairness, and one budget of crashes for all processes.** TLC does not take a negative number in a config, so use a large one for "no limit", and stop each counter at a small cap there, or the model has no end. Keep one config with no limit: it shows that no design keeps "eventually" when crashes never stop, and the record says so.
- **The promise is about the crash,** so a config with no crash never runs the steps that matter, and their count is `0:0`. Commit a config with crashes too, and name each step that a config never runs.
- **Check the fix under crashes too.** A fix that leaves a message which is offered again without end can keep the other messages from their turn.
- Not covered by a kill of a process: a crash of the machine or a loss of power before data is on the disk, a network file system where a rename is not atomic, and a lock wait that times out. List them as assumptions.

## Replay and trace with real processes

- **Run the unchanged code in child processes, one step at a time.** In each child, replace the calls that are steps (the system calls on the shared folder, the `execute` of the database connection). Each replaced call writes its name to a pipe to a controller and waits for the word to go on. The controller lets one process take one step at a time.
- **Kill at a gate:** send `SIGKILL` while the process waits before step X. Then every earlier step is done, and none after.
- **The controller is the only writer of the log.** It logs a step when the process has reached its next gate or has ended, so the order of the lines is the order of the steps. It reads the database and the folder between steps for the values of the rules.
- Read the pipes unbuffered. A buffered read makes a step look stuck.
- **Map the ids that the code makes,** such as a UUID, to the ids of the model in the controller. When the code works in the order of such names, as with a sorted listing, that order is random for each run: give the model a variable for it, with every order as a first state.
- **To replay a finding, follow TLC's path** action by action, and assert the end state from the database. On a step that differs from the path, let the harness report it and go on to the next run: a harness that stops at the first one leaves no logs for the trace check.
- **A fix that changes the steps,** such as one transaction around two statements, cannot run in a harness that waits for the old steps. Show it in the model, and check a patch of it with the tests of the report.
- **A test of a double effect must make the two handlers overlap.** With one handler after the other, it can pass on the code with the bug.
- **A log that replays a finding breaks the rule,** and the trace check exits 12. Give such logs a config with no rule that the code breaks, and assert the break in the harness.
- For the test that goes with a report, a smaller way works: a child process in which the call after the step is replaced by `os._exit`, or the same in another language.

## The record

- Say what one step is, and the result of each trial of a system call, with the operating system and the file system.
- Name each constant with its plain meaning: where a crash can come, how many, who restarts, and where a time limit can run out.
- Say which rules hold with no crash, which with a bounded count of crashes, and which never.
- Say that a CI step must run each config with crashes: the action runs only the config next to the spec.
