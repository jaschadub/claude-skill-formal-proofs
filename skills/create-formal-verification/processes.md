# Messages, crashes, and several processes

<!-- Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE. -->

Read this when the promise spans several processes: a queue between them, a database or a folder that they share, a time limit after which work is offered again, or a promise that holds "also when a process crashes". It adds to `SKILL.md` and to the guide of the language, and replaces none of them. It comes from a test on an order service with a queue of files, a database, and worker processes, where the model found seven breaks of "charged exactly once" and each was replayed with real processes, and from a second test on a real job queue library with a real Redis, where four breaks were replayed.

No tool runs several real processes under every order of their steps and every crash. So write a TLA+ model, check it with `tla-check`, and tie it to the code with a harness that runs the real processes one step at a time (below). Say first that this is a model check within its bounds.

## What one step is

- **One step is one system call on what the processes share, or one statement on the database** when each statement is a transaction of its own. A transaction is one step. Read how the code opens its connection: with autocommit, two statements are two steps, and a crash can come between them.
- **A call that makes or ends a process, such as a fork, is a step too,** although it is on nothing shared: a kill before it and a kill after it leave different processes behind.
- **A crash can come between any two steps.** A charge and the mark that it is done, as two statements, are the usual break of "exactly once".
- **Find out by trial what each call does,** and write the result into the record. In the test run:
  - a rename is the atomic claim, and the loser gets an error;
  - a rename onto the same name never fails, so it claims nothing;
  - a rename keeps the file's time of change, so a time limit that is measured by it starts at the write, not at the take.
- **With Redis** (measured on Redis 8.10 with redis-py 8.2):
  - One step is one round trip: one command, one `MULTI ... EXEC` block, or one Lua script. A client pipeline with a transaction is one block. A pipeline without one is one step for each command.
  - A kill before `EXEC` applies nothing. A command that fails inside `EXEC` or inside a script does not undo the others: it is one step, but not all or nothing.
  - `WATCH` guards only the keys that it names. A read, a `WATCH`, and an `EXEC` are three steps, and a change of any other key between them goes through.
  - `LMOVE` is the atomic claim, and the loser gets nil, not an error. A blocking pop is done when the server did it: a client that is killed before it reads the reply has taken the item, and with `BLPOP` the item is then in no list.
  - `SET NX EX` is a lock with a time limit. A `DEL` by an old holder removes the lock of a new one.
- **A process acts on a snapshot.** After a listing of a folder or a `SELECT`, the names and rows can be gone or changed. Keep the snapshot as state of the process, and make each later use a step of its own that can find the item gone.
- **A write can be a snapshot too.** Code that saves an object writes every field as the process read it, not only the field that the function is about. Read on the wire what each step sends, with `MONITOR` in Redis or the statement log of a database, and model the write of every field that a rule reads. In the second test, a late success wrote back a count of retries that was used up.
- A read or a write that no other process can see, such as a temp file with a random name, can be part of the next step. Say where you do it.

## Messages

- Give each message a state, such as none, written, queued, taken, gone, and a step for each change.
- **Model what the queue does on its own.** A queue of files loses nothing and offers a message again after the time limit. **First find out who offers a message again: the broker, or code of the clients.** A Redis list offers nothing again: a popped item is gone, and every second delivery is a cleanup that some client runs. Model that cleanup as steps of a process, with its snapshot, and find every caller of it: in the second test, a status command ran the same cleanup with no lock. A broker can also deliver twice and out of order by itself: give the model a step for each, and say which you left out. A broker with acknowledgments or a time limit of its own was not tested.
- **Count what the rule is about,** such as the charges of each order. The code often stores only a sum, so the model needs a variable that the code does not have. In the harness, make the count readable, such as with one account for each order.
- **Split "exactly once" when it breaks:** at most once is an invariant, at least once for a message that reached the queue is a rule that something eventually happens, and "stored implies queued" is a third. Report which the code keeps. When the code retries, "at most once" becomes "at most once plus the retries", and that count does not see two runs at once. Add: never two runs at the same time, never a run after a stored success, and a stored end state is not replaced.

## Time limits without a clock

- Give each message one flag for "its time is over", and a step that sets it at any time. The steps of the code that reset the time clear the flag.
- **A time limit belongs to what the code stamps:** a message, one run of it, a lock, or a marker key. Give each a flag of its own, and check which steps really reset it: a marker that is keyed by the message id and never deleted keeps its age across a retry.
- Add a constant that says in which cases the flag may be set: while the message waits, while a live worker holds it, while a dead worker holds it. Each case is a separate question. Two of the seven breaks needed no crash: a message that waited longer than the limit, and a worker that was slower than the limit.
- For a rule that something eventually happens, give the step that sets the flag weak fairness: time passes.
- In the harness, make a file old by setting its time back. Do not wait. For a broker, find how each limit is kept. A time in a value or a score is compared with a client's clock: set it back. A key's time to live is the server's: shorten it, such as with `PEXPIRE key 1`. A wait inside the broker or a period of the process's loop has no sleep to replace: use the code's own setting for it, and say in the record which settings the harness changed.

## Crashes

- **A crash is a step that is possible wherever the next step of the process is in a constant,** such as `CrashAt`. With every step in it, a crash can come anywhere. With one step in it, the path to one finding stands alone. Two findings with the same crash points are not parted by it: switch on the fix of the first to find the next, because TLC gives one cause for each rule.
- **A crash loses the memory of the process, and nothing else.** Rows and files stay, also the half-done ones, such as a temp file or a claimed message. A model that cleans them up at the crash hides the finding.
- **Find by trial which child processes a kill of the parent ends.** A forked child can live on with a copy of the parent's memory, and take its later steps with no parent. Give the model one process for each, a crash step for each, and let the child's steps go on after the crash of the parent. That was the main finding of the second test.
- **Keep "killed" apart from "ended by its own error",** and write a rule for it, such as "no worker ends on an error that it did not catch". A worker that ends on an error that it did not catch is a finding with no kill at all. Two of the seven breaks were of this kind.
- **A process that only waits needs a step,** as `tla-check` says for a rule that something eventually happens: a loop that sleeps and looks again is a step that changes nothing. In the harness, replace the sleep.
- **The restart is a step behind a constant.** Say in the record who restarts a process: the code, or a supervisor that the repo does not hold. A rule that something eventually happens rests on that. A restarted process is a new one: reset every variable of its memory in the restart step, and make what the old process held, such as a lock or a claimed message, belong to no live process. When a time limit asks "is the holder dead", the answer must stay yes after the restart, or TLC reports breaks of such a rule that the code does not have. Check by trial whether the code lets a new process take the old name.
- **Give a crash no fairness, and one budget of crashes for all processes.** TLC does not take a negative number in a config, so use a large one for "no limit", and stop each counter at a small cap there, or the model has no end. Keep one config with no limit: it shows that no design keeps "eventually" when crashes never stop, and the record says so.
- **The promise is about the crash,** so a config with no crash never runs the steps that matter, and their count is `0:0`. Commit a config with crashes next to the one without, and name each step that a config never runs.
- **Check the fix under crashes too.** A fix that leaves a message which is offered again without end can keep the other messages from their turn.
- Not covered by a kill of a process: a crash of the machine or a loss of power before data is on the disk, a network file system where a rename is not atomic, and a lock wait that times out. List them as assumptions.

## Replay and trace with real processes

- **Run the unchanged code in child processes, one step at a time.** In each child, replace the calls that are steps (the system calls on the shared folder, the `execute` of the database connection). Each replaced call writes its name to a pipe to a controller and waits for the word to go on, and writes again when the real call has returned. The controller lets one process take one step at a time. In a child that the harness does not import, a starter script puts the replacements in and then calls the code's own entry.
- **For a client library, replace the methods that make one round trip,** and compare one stepped run with the server's own log of commands: the counts must match. What passes below the gate, such as the handshake of a connection, goes into the record.
- **When the code forks, a pipe from the controller is shared by parent and child.** Let each process open a connection of its own to the controller, such as a Unix socket, and let the child close the parent's one right after the fork. Not measured with a pipe: the test used sockets from the start.
- **Kill at a gate:** send `SIGKILL` while the process waits before step X. Then every earlier step is done, and none after. A process that waits for a child or in a blocking call is at no gate, and a kill there is a case of its own: allow it, and name the state in the log. Before each kill, confirm that the process still runs: a kill of a process that has ended succeeds without an error while it is a zombie, and the log then names a kill that never happened. A kill between the last step and the exit has no gate: keep it in the model, and say in the record that the harness does not make it.
- **The controller is the only writer of the log.** It logs a step when the real call has returned or the process has ended, so the order of the lines is the order of the steps. Do not wait for the next gate: a process that forks and waits for its child, or that blocks in a pop on an empty queue, does not reach one. Keep in the controller where each process is, so that it never waits for a timeout to learn it. It reads the database and the folder between steps for the values of the rules.
- Read the pipes unbuffered. A buffered read makes a step look stuck.
- **The real code makes many calls that the model has no step for:** in the second test, about two for each step of the model. Gate them all, log each as a step that changes nothing, and compare the values of the rules after it as after any step. Then a call that was wrongly left out of the model fails the trace check. Tell the steps of the model apart by the function of the code that makes the call, from the call stack, and by the exact key, not by the command alone.
- **A step of the model that is no call,** such as "the wait for the child returned", is logged by the controller from what it sees next. Write down the rule that it uses.
- **Give the harness a broker of its own,** and say in the record that the harness empties it. Run one harness at a time on it.
- **Map the ids that the code makes,** such as a UUID, to the ids of the model in the controller. When the code works in the order of such names, as with a sorted listing, that order is random for each run: give the model a variable for it, with every order as a first state.
- **To replay a finding, follow TLC's path** action by action, and assert the end state from the database. On a step that differs from the path, let the harness report it and go on to the next run: a harness that stops at the first one leaves no logs for the trace check. Say for each path what it needs: kills, time limits, or a process that stops for long between two steps that follow each other at once. Report the last kind as a weakness with its condition, and look for a path without it.
- **A fix that changes the steps,** such as one transaction around two statements, cannot run in a harness that waits for the old steps. Show it in the model, and check a patch of it with the tests of the report.
- **A test of a double effect must make the two handlers overlap.** With one handler after the other, it can pass on the code with the bug.
- **A log that replays a finding breaks the rule,** and the trace check exits 12. Give such logs a config with no rule that the code breaks, and assert the break in the harness.
- For the test that goes with a report, a smaller way works: a child process in which the call after the step is replaced by `os._exit`, or the same in another language.

## The record

- Say what one step is, and the result of each trial of a system call, with the operating system and the file system.
- Name each constant with its plain meaning: where a crash can come, how many, who restarts, and where a time limit can run out.
- Say which rules hold with no crash, which with a bounded count of crashes, and which never.
- Say that a CI step must run each config with crashes: the action runs only the config next to the spec.
