# TypeScript and Node targets

<!-- Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE. -->

Read this when the code to verify is TypeScript or JavaScript that runs on Node. It adds to `SKILL.md` and replaces none of it. It comes from a test on the token handling of a real SDK, with Node 26, vitest 3, and fast-check 4. It covers async code in one process. For several processes or workers, write a model, and say that no test covers them.

## Pick the checker

| The question | Checker | What a pass means |
|--------------|---------|-------------------|
| Can calls of async code take their steps in a bad order? | A test of the real code that holds each call at its `await` and tries every order of the steps (below), and a TLA+ model with `tla-check`, tied by a trace from the same test | The test covers every order up to its depth, for the calls that it offers. The model covers every order in the model, with no depth. |
| The same, as a quick first look | `fc.scheduler()` of fast-check on the real code | Random orders only. |
| Timers, time-outs, expiry | Fake timers of the test runner on the real code | Only the cases that the test makes. |
| Several processes, workers, a shared store | A TLA+ model only | The model. |

No tool was found that runs real TypeScript under every order of its async steps, as loom does for Rust. Say so first when the user asked for a formal verification, and deliver the test with the model. The test is cheap to write here, because a stretch of code with no `await` runs whole. In the test run, a harness of about 370 lines made 2,500 runs in 7 seconds at depth 9, and found each broken rule with the shortest path to it. Depth 14 took 72 seconds, and depth 30 did not end. A search whose choices have the budgets of the model, such as two calls and one clear, ends by itself with no state cut off: in a second test run, 93,736 runs in 11 seconds. TLC covered the same system with no depth: 213,003 states in 3 seconds. So keep both.

`fc.scheduler()` needs no change to the code. When the package is outside the repo, import it by the absolute path that `require.resolve` gives, from a test file inside the runner's root. In use: wrap each awaited dependency with `s.schedule(...)`, start the calls, and `await s.waitAll()`. It caught a seeded break at once. It picks orders at random and does not fire timers, so a pass is evidence and not a proof. A check that the record keeps cannot use a package that the repo lacks: install such a tool outside the repo for a first look, and build the kept test on the repo's own runner.

## Where a model of async code goes wrong

A step of the model must be one indivisible step of the code. Check each of these against the code, and cite its line in the record.

- **One step is one stretch of code with no `await` in it.** No other call, promise callback, or timer runs inside it.
- **An `async` function with no `await` in its body runs whole inside its caller's stretch.** So `await f()` is: all of `f` up to the first `await` of `f` in this step, and the rest of the caller in a later step. A model that puts a write of `f` after the wait is wrong.
- **A check before an `await` and a write after it are two steps.** Every race in the test run was of this kind: a method read the current token, awaited, and then wrote without a second look. On the plain code, `await Promise.all([auth.logout(), auth.refreshToken()])` left a token in use after the logout.
- **What can run at an `await` depends on what the awaited call does.** When it ends without I/O, only code that is started already or queued as a promise callback runs in the wait. A timer or an I/O callback cannot. Put this in the model as a constant, check the rules with it, and report the case without it as a bug that waits for the first I/O behind that `await`.
- **Do not count promise turns.** The wait of one `await` took 1, 2, or 3 turns, by how the awaited thing was built. A refactor that changes no step changes these counts. Model "the wait ends before any timer" or "anything can run", never "after 2 turns".
- **TLC's shortest path can be one that promise order forbids, while a sibling path is real.** Two waits of one turn each end in the order in which they started. When a path does not show on the code, try the other start order before you call the model wrong.
- **A token or id made from the clock is part of the state.** A token signed with a time in whole seconds and no random part is the same string twice in one second. A model with "a fresh token each time" passed where the code revoked the token that it then held. Read how each id, token, and key is made before you model it as fresh.
- **A promise that nobody awaits** is a call that the caller cannot order, and its failure reaches nobody, as in `setTimeout(() => { this.refresh(); }, ms)`. Model its failure as a step, and ask what the code does after it.
- **`Promise.race([work, timeout])` stops nothing.** The loser runs on, and can still write. A timer that the code does not clear stays, and keeps Node from its exit: 100 calls that ended left 100 timers. Count them with `vi.getTimerCount()` under fake timers, and with `process.getActiveResourcesInfo()` under real ones.
- **Check the edges of a timer's delay.** A computed delay of zero or less can mean that no timer is set. A delay of more than 2^31-1 ms, about 24.8 days, makes Node use 1 ms: the test run saw 165 refreshes in 200 ms. Show it with real timers: the fake timers of vitest did not fire the same way in every case.
- **A timer that fires implies that time passed,** so the model's timer step moves its clock too. `clearTimeout` on a timer that fired does nothing, and the field that holds its id is not cleared when it fires.
- **A shared promise,** such as `this.refreshing ??= this.doRefresh()`, makes overlapping calls safe only when the check and the store are in one stretch, and the field is cleared in `finally`. If not, one failure goes to every later caller.
- **Each process and each worker has a heap and an event loop of its own.** A list in memory, such as a list of revoked tokens, is one for each process.

## Try the orders on the real code

- **Hold a call at its `await`** by replacing the awaited method on the object. `private` is a compile-time rule only: `(auth as any).validator` reaches the member. Call the real method first, and hold only the promise:

  ```ts
  const real = owner[name].bind(owner);
  owner[name] = (...args) => {
    const result = real(...args); // what it does before its first await happens now
    return new Promise<void>(open => { call.open = open; }).then(() => result);
  };
  ```

  If you hold before you call the real method, a write that the code makes inside its caller's stretch moves to a later step, and the test checks other code than the product.
- **After each step, let every promise callback run,** with a real `setImmediate`: `await new Promise(r => setImmediate(r))`. Then one choice of the search is one stretch of one call.
- **Fake only the timers that you need:** `vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout', 'Date'] })`. The default also fakes `setImmediate`, and the wait above never ends. `vi.advanceTimersToNextTimer()` moves the clock to the next timer and fires every timer that is due at that time, with no promise callback between them. Two calls that start in one stretch have such timers, so the model needs one step for them together, or the test must give them different delays. `vi.setSystemTime(...)` moves the clock and fires nothing. Read the state of a path before you switch back to real timers: after `vi.useRealTimers()`, `Date.now()` is the real clock.
- **Search breadth first:** make fresh objects for each path, replay the path, skip a state that was seen before, and check the rules at each new state. The first break is then the shortest path. Print the count of runs, of distinct states, and of states cut off at the depth.
- **The key that says "seen before" must hold everything that decides which code runs next.** In the test run, two kinds of login had the same key, so the search never ran the second half of one, and passed. Line coverage showed it. Run the search once with coverage, and explain each line of the covered functions that never ran.
- **Make the harness fail on what the model has no step for:** a call that still waits after its one release, and a call that ended with no `await` where the model has one.
- **A search that meets known findings on every run** expects exactly the set of rules that the code breaks. It fails when another rule breaks, and when a finding stops breaking.
- **For the test of a finding, use no harness:** start the calls in one stretch and await them together, as with `Promise.all` above. It shows the bug on the plain code, and a maintainer can read it.

## Tie the model to the code with a trace

- **Log from the search,** one line for each step, with the state of the real objects after the step. Read that state through the product's own readers, not from the bookkeeping of the test.
- **Name the action from what the code did, not from what the test asked.** A refresh that returned before its `await`, because there was no token, is another action than one that reached it.
- **Each log costs one JVM,** so write a sample of the runs, such as every 40th, and say so in the record. Write the logs outside the repo.
- **Logs of overlapping calls need a config of their own,** without the rules that the code breaks there. If not, the trace check exits 12 on the finding.

## Run it

- Run one file from the folder that holds the runner's config: `npx vitest run PATH`. The root config can differ from a package's own `test` script, which can be stale.
- **A test file anywhere in the repo joins the default run,** when the config includes `**/*.test.ts`. Give the search a small depth by default and the full depth by an environment variable. Do not skip it: a search that is skipped checks nothing.
- **Test runs that can lie:**
  - `-t` with a name that matches nothing exits 0, with every test skipped. So say in the record what a pass prints, with the counts.
  - An unhandled rejection fails the run while every test passes, and vitest names the last test that ran. Read the `Errors` line.
  - vitest cuts long values in a failure message. Put the rule and its path in the message argument of `expect`.
- vitest does not check types. `tsc` with a file argument ignores `tsconfig.json`, so give the harness folder a `tsconfig.json` that extends the root one with `noEmit`, and run `npx tsc -p` on it.
- The text report of coverage cuts long lists of lines. Use `--coverage.reporter=json` with `--coverage.include` for the covered files.

## Scratch copies and patches

- **A scratch copy needs `node_modules`,** which git ignores. A link to the repo's folder works for packages from the registry.
- **npm workspaces put links into `node_modules` that point back at the repo.** An import by package name then runs the code of the repo, not of the copy, and a seeded fault passes. Import by relative path, or check the runner's aliases, and confirm once that a fault in the copy fails the test.
- Leave `.env` files out of the copy.
- **A fix that adds an `await` adds a step.** The harness stops at it, which is right: the model needs the step too. Say which fixes you showed on the real code and which only in the model.

## The record

- Define a step for this code in one paragraph, and give a table from each stretch of code to the model's step and the search's choice.
- Name each assumption as a constant of the model with its plain meaning, such as "callers await each call" and "each awaited call ends without I/O".
- List the private names that the harness reaches into. A rename breaks the harness, not only the cited lines.
- `drift.sh` cannot hash `node_modules`. Cite the `package.json` line of each package that the check trusts, and name the installed version in the text, because a `^` range does not pin it.
- Give the depth of the search, the count of states cut off, the sample of the trace, and what a pass prints.
- Say for each finding whether it shows on the plain code, or only with a promise that the test holds.
