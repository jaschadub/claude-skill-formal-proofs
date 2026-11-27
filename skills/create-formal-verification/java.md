# Java targets

<!-- Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE. -->

Read this when the code to verify is Java, or another language on the JVM. It adds to `SKILL.md` and replaces none of it. It comes from a test on the circuit breaker of a real library, with Java 25, Maven 3.9, Lincheck 3.7, and jcstress 0.16.

## Pick the checker

| The question | Checker | What a pass means |
|--------------|---------|-------------------|
| Can threads take their steps in a bad order, in one JVM? | Lincheck, `Lincheck.runConcurrentTest(n, () -> { ... })`, on the real classes with no change to them | Every order that it tries for the threads that the block starts, with a switch at each read and write of a shared field and at each monitor. |
| The same, as a statistic on real hardware | jcstress | Only the orders that happened in some millions of runs. It runs under the real memory model of the JVM and the CPU. |
| The same, for more threads, a clock, another process, or the steps inside a call | A TLA+ model with `tla-check`, tied by a trace from a test of the real code | Every order in the model, within its bounds. |
| Does a function hold for every input? | jqwik with generated inputs, which is not a proof. JBMC, KeY, or OpenJML for a proof; not tested here. | |

- **Lincheck first.** It ran on Java 25, found a real bug in 1.3 seconds from a test of two threads on the public API, and caught a seeded fault. Its output names each field read, each `MONITORENTER`, and each switch, so the path can be told in the code's words.
- **Lincheck stops when it has no order left.** Asked for 10,000 orders of a small test, it ran 33. It prints nothing on a pass, so have the test print what it ran. Say in the record that "every order" means every order at Lincheck's switch points, for that count of threads.
- **jcstress is a second opinion.** It saw the same bug in 2 to 4% of runs, in 51 seconds. It needs its annotation processor at compile time and its own `Main`, and it wants all cores: pass `-c 2`. Use it for a question about the memory model, or to say how often a finding of Lincheck shows.
- **Java PathFinder did not build on Java 25.** Its build is for Java 11. Do not plan on it without that toolchain.
- **Lincheck and a model answer different halves.** In the test run, Lincheck found one finding by itself. The model found four, with the shortest path to each, and showed which fixes make every rule hold. Seed a fault before you trust either.

## Where a model of Java code goes wrong

A step of the model must be one indivisible step of the code. Check each of these against the code, and cite its line in the record.

- **One read or write of a `volatile` field is one step, and so is one call on an atomic class,** such as `AtomicReference.get` or `AtomicInteger.getAndUpdate`. `get()` and then `set()` are two steps. `x++` on a `volatile` field is two steps. The function that `getAndUpdate` takes can run more than once, so the call is one step only when the function has no side effect.
- **A `synchronized` method is one step only when everything in it stays inside its monitor.** Split it at each access to something that another thread reaches without this monitor, and at each call that takes another monitor. In the test run, one `synchronized` method was four steps: it wrote counts, decided, called the owner, which takes a second monitor, and gave back a permit, which is an atomic.
- **A monitor guards an object, not a class or a role.** When the code replaces the object, as in `state.set(new HalfOpenState(this))`, a thread that read the old reference locks the old object, and a thread that read the new one locks the new object. Both are inside the `synchronized` method at once. Give each instance an id in the model, and a monitor for each. Three of the four findings came from this.
- **A thread that waits for a monitor has read what it read.** `state.get().recordSuccess()` reads `state` first and then waits. Model the read and the entry as two steps.
- **Monitors are reentrant.** The model needs an owner for each monitor, not a flag, when one thread can enter twice.
- **Two objects can share a third.** A constructor that takes a field of another object, such as the counts of the previous state, makes two monitors guard one object. Look for such constructors.
- **A call back into the owner is a fresh read.** When a state object calls `breaker.halfOpen()` and then `breaker.tryAcquirePermit()`, the second call reads the state again. Model each as a call of its own.
- **Time is a step of the outside.** Model `System.nanoTime() - start >= delay` as a flag, and a step that sets it. In the trace check that is the step that the code cannot log. Run the trace tests with a delay that is always over or never over.
- **Look for user code under a lock:** a listener or a functional interface that is called inside `synchronized`, and `future.complete(...)` there, which runs every callback of the future. Model it, or name it in the record as not covered.
- **`CompletableFuture`: `complete` and `cancel` are one atomic step, and only one of them wins.** The callbacks run after it, in the thread that completed, or at once in the caller when the future is complete already. Code that ignores the result of `complete(...)` hands something to a future that was cancelled: in a second test run, a permit went to a waiter that had given up, and was lost. Model the completion as a step, and what each side does after it as later steps.
- **The memory model.** TLC and Lincheck assume that every thread sees every write at once. That is right only when each shared field is `volatile`, `final`, an atomic class, or touched only inside one monitor. Read each field of the covered classes, and write the result into the record with the fact that no tool checked it. A plain field that is read outside its monitor can be stale.
- **`java.util.concurrent` collections:** one call, such as `putIfAbsent` or `computeIfAbsent`, is one step. Two calls are two steps, also `containsKey` and then `put`. `size()` and iteration are not a snapshot. Not tested here.

## Force or explore orders on the real code

- **Force one order with a monitor and `Thread.State.BLOCKED`,** with no sleep and no change to the code. It works where the thread to stop takes a monitor next:

  ```java
  Object halfOpen = breaker.state.get();              // a test in the same package reaches the field; a private one needs reflection
  Thread success = new Thread(breaker::recordSuccess);
  synchronized (halfOpen) {                           // the monitor that the other thread needs next
    success.start();
    while (success.getState() != Thread.State.BLOCKED) Thread.sleep(1);  // it has read the state, and waits
    breaker.recordFailure();                          // the steps that must come between
  }
  success.join();
  assertTrue(breaker.isOpen());
  ```

  Give the loop a time limit. Use this for the test of a finding: a maintainer can read it. For a window between two calls on a future, a callback that the test adds with `whenComplete` can run the steps between. For other windows between two atomic operations, use Lincheck.
- **Explore with Lincheck inside a normal test.** Build every object inside the block, start two threads, join them, and throw an `AssertionError` when a rule breaks. Write the assertion as what every order of the whole calls gives, such as "the breaker ends open".
  - Lincheck rolls back state that the block writes, also a counter of the test. Count with a printed line, and count it in the output of the build, not in the report files.
  - Add `-XX:+EnableDynamicAgentLoading` to the test JVM. Lincheck leaves `lincheck-bootstrap*.jar` files in the temp folder.
  - Start with two threads and one call each. The model covers more threads.
- **A path with no race can be the finding.** One finding here needed three overlapping calls and no switch between two instructions. Say for each finding whether it needs a race, and how wide the window is: "the whole of a method" or "two statements".

## Tie the model to the code with a trace

- **The methods of `AtomicReference` and `AtomicInteger` are `final`,** so a subclass cannot log them. What a test can hook with no change to the code:
  - a subclass of the class under test, in the same package, that overrides the methods which the inner objects call back;
  - a wrapper around a field of an interface type that is not `final`;
  - reads of package-private state between steps.

  A `new` inside the code, a `final` method, a static call, and `System.nanoTime()` cannot be hooked this way.
- **A thread that waits inside a blocking call is not at a stop.** Run the trace tests with a time limit of zero or with the interrupt set before the call.
- **With no place to log inside a step, run one thread at a time.** A scheduler of about 110 lines stops each thread at each hook, and a seeded random choice picks who goes on. Then a line that a thread writes after a step is at the right place in the log.
  - A thread must never wait for a monitor between two stops, or two threads run at once. Stop it before the call that enters the monitor, and let it go on only when no stopped thread is inside that monitor.
  - That joins "read the reference" and "enter the monitor", so the trace runs never take the orders between those two. Say so in the record, and let the model and Lincheck cover them.
  - Sort the threads by name before the random pick, or one seed gives two runs.
  - Make the wrapper throw on a call that it does not log.
- **The trace check and the order tests catch different faults.** A changed threshold passed every Lincheck test and failed the trace check. A permit taken in two steps failed Lincheck and passed the trace check. Name for each fault patch the check that it must break.
- **A model config with `SYMMETRY` needs model values, and a trace config needs strings,** so they are two configs. Runs with other settings, such as other thresholds, need a config and a folder of logs of their own.

## Build and run

- **Put the harness in a Maven project of its own,** with `<sourceDirectory>` set to the sources of the product and its own test dependencies. It needs no `mvn install`, it cannot run a stale jar, and a fault patch in a scratch copy is compiled in. It works when the module has no generated sources and no dependencies. If it has, depend on the module's artifact, and say in the record that it must be installed first.
- One test class: `mvn -pl MODULE surefire:test -Dtest=CLASS` runs with no recompile. `mvn -q` hides the `Tests run:` lines, so do not use it for the run that the record describes.
- Limit the build with `-T1`, and keep a scratch run away from the user's files with `-Dmaven.repo.local=FOLDER`.
- Java 25 still compiles `-source 1.8`. Test code in such a project cannot use newer syntax.
- **Test runs that can lie:**
  - An old TestNG (6.9) on Java 25 lost the names of the tests, and the last summary line gave a wrong count. Read the line that ends with `in <suite>`, or use a newer TestNG and Surefire in the harness (TestNG 7.5.1 with Surefire 3.2.5 worked), and have the test print a line of its own.
  - A `SkipException` from `@BeforeMethod` counts as a failed setup. Throw the skip from the first line of each test.
  - JaCoCo does not see code that runs inside Lincheck. Its numbers are those of the plain tests only.
  - A fault patch that did not apply looks like a fault that was not caught. Print `git status --short` after each `git apply`.
- **TLC needs temp space.** With `TMPDIR` on a RAM disk it failed with `Disk quota exceeded`, which is not an error of the spec. Grow the bounds in steps, and prefer one budget of calls for all threads over one for each thread.
- A model with an id for each object prints large states. Filter the path: `grep -E '^Error: Inv|^State [0-9]+: <'`.

## The record

- Give the versions of Java, the build tool, Lincheck, and the test runner.
- Say for each check what a pass covers, in a table. A reader takes "Lincheck passed" for more than it is.
- Say what one step is, with the reason for each joined step.
- Give the reading of the memory model: each shared field, and why a write to it is seen at once.
- A cited text must not repeat further down, and Java repeats. Use an entry for each method, start it at the signature, and cite the parameter types of an overload.
- Cite the helper classes that the model assumes. For an assumption about a library, cite the line of its version in `pom.xml` or `build.gradle`.
- A fix that needs a design change stays a switch of the model. Say that it is not a patch for the code. A trace test that throws on a call that it does not log refuses code with a fix patch: say so, or teach it the new call.
- A test that passes while the bug is there can report the finding as gone under an unrelated fault. When it does, replay the finding before you believe it.
- Name the harness file that must follow a change to the covered code.
