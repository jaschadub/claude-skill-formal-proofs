# Python targets

<!-- Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE. -->

Read this when the code to verify is Python. It adds to `SKILL.md` and replaces none of it. It covers code that uses threads. It does not cover asyncio. For code that runs in several processes, also read [processes.md](processes.md).

## Pick the checker

No established tool runs real Python threads under every order of their steps, as loom does for Rust. The packages that claim to were new and little used in November 2026. Do not build on one unless it first catches a fault that you seed.

So for a question about the order of steps, write a TLA+ model, check it with `tla-check`, and tie it to the code with a trace. A property test, such as one with Hypothesis, tries random cases: a pass is evidence and not a proof.

## Where a model of Python code goes wrong

A step of the model must be one indivisible step of the code. Check each of these against the code, and cite its line in the record.

- **The GIL does not make a statement one step.** A read followed by a write is two steps, also in one statement such as `count += 1`, and also for a check on a dict followed by a change to it. Another thread can run between them. One call on a built-in container, such as `list.append` or `set.add`, is one step. Several steps under a lock are one step only toward code that takes the same lock. Code that reaches the same data without that lock, such as a `Queue.get` in another thread, can run between them, so keep them apart in the model.
- **A call that can wait is a step that may never happen.** `Queue.put` on a bounded queue waits for room, `Queue.get` waits for an item, and `lock.acquire` and `thread.join` wait without a limit unless they get a timeout. Give the model a waiting state for each, and write a rule for each place where the code must never wait.
- **`with lock:` frees the lock on every way out,** also on an exception, and the code after the block runs without it. `lock.acquire()` with no `try` and `finally` leaves the lock held when the code between raises.
- **A daemon thread stops in the middle of its work when the process exits.** Work that it had accepted is lost. Model the exit as a step that can come at any point of that thread.
- **`sys.exit` in a thread ends only that thread,** and prints nothing. The other threads go on.

## Tie a model to the code with a trace

- **Log from the test, and leave the product code as it is.** Subclass the class under test, let its own `__init__` run, and then make the objects that it built log. Keep those objects: a queue or a lock that you build yourself hides a change to the real one, such as a new bound. Wrap the real lock in an object that logs after `acquire` and before `release`, because a `threading.Lock` has no subclass. Replace a set or a dict with a subclass of it that logs. Wrap a function with `unittest.mock.patch`.
- **Log while the step holds what makes it one step.** For a step under the code's own lock, log from inside that lock. For `queue.Queue`, set `_put` and `_get` on the real queue object to functions that call the real ones and then log: `put` and `get` call them while they hold the lock of the queue. A `put_nowait` that raises `queue.Full` calls neither, so treat it as a step that the code cannot log, as `tla-check` describes.
- **A free run gives one order.** Threads that do little work run one after the other, and every run writes the same log. Add small random pauses in the test's wrappers, or fix an order with `threading.Event`. Write one log for each run into a folder: `trace.sh` on that folder says how many logs were distinct. A pause may come while the code holds its lock: that changes the timing, and not the orders that can happen. Say in the record how many orders the trace covered.
- **A bare read or write of a global has nothing to wrap.** For a step such as `seen = count`, set a trace function in the thread with `sys.settrace`. On a `line` event of the function under test, it logs, or it waits on a `threading.Event` until the test lets the thread go on. That holds a thread between two lines without a change to the code. Confirm that the hook fired, such as with a timeout on the event: a hook that never fires lets the test pass.
- **A free run rarely switches between two plain statements.** On CPython 3.12, 3.13, and 3.14 with the GIL, about 70,000 free tries each never put a thread between a read and the write after it. So the test that shows such a bug must force the switch, as above. Say in the finding that the path needs a switch between two lines, on which versions free runs did not show it, and whether a free-threaded build was tried.
- **Under a test, `sys.exit` only raises `SystemExit`.** The process lives on, and a daemon thread keeps running and keeps logging. End each log at the step that stands for the exit, and write one log for each scenario.

## Run it

- A harness that imports the product code writes `__pycache__` folders into the repo. Set `PYTHONDONTWRITEBYTECODE=1` for it.
- A test file outside the repo, such as the test of a report, does not run by its path with `python3 -m unittest`. Run it from its own folder, with `PYTHONPATH` set to the repo.
- `from api import QUEUE` gives the importing module a name of its own. A test that sets `api.QUEUE` must set the copy in each such module too.

## The record

When the model trusts a step of the standard library, such as `threading.Lock` or `queue.Queue`, `drift.sh` cannot hash it. Write that assumption in the record, with the Python version that you ran.

`examples/counter` in the `formal-proofs` plugin, https://github.com/jaschadub/skill-formal-proofs, is a Python counter with its model and record.
