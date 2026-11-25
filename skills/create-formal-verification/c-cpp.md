# C and C++ targets

<!-- Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE. -->

Read this when the code to verify is C or C++. It adds to `SKILL.md` and replaces none of it.

## Pick the checker

| The question | Checker | What a pass means |
|--------------|---------|-------------------|
| Does a C function hold for every input: no read or write out of bounds, no overflow, an invariant of a data structure? | [CBMC](https://www.cprover.org/cbmc/) or ESBMC, on the real code | Every input up to the sizes in the harness and the unwind bound of each loop. |
| The same, for C++ | The same, when it can read the code | CBMC reads only a part of C++. It failed on the headers of the standard library of GCC 15, and it rejects lambdas and range-for loops. Try it on the real file first. When it cannot read the code, say so. |
| The same, when no verifier reads the code | A test of the real code with generated inputs under the sanitizers | Only the inputs that the test made. It is not a proof: say so. |
| Can threads take their steps in a bad order? | ThreadSanitizer (`-fsanitize=thread`) for data races, and a TLA+ model tied by a trace for the order of steps | ThreadSanitizer sees only the runs that the tests make. The model covers every order in the model. |
| Can tasks, interrupts, a reset, or a device take their steps in a bad order? | A TLA+ model with `tla-check` | Every order in the model. |

When the user asked for a formal verification and the check is a test, say so in the first line of the hand-off, and say what a proof would take: another verifier, or a copy of the code restated in C that a verifier reads, which needs the user's consent.

## CBMC on C code

- Write a harness function that makes each input with a `nondet_` function, bounds its size with `__CPROVER_assume`, calls the real function, and states the rule with `__CPROVER_assert`. Run `cbmc file.c --function harness --bounds-check --pointer-check --unwind N --unwinding-assertions`. With `--unwinding-assertions`, a bound that is too low fails instead of passing in silence.
- Put each input in a block of exactly its size, from `malloc(n)`, so that a read one byte past the end fails.
- CBMC's `malloc` may return NULL, also for `malloc(0)`. Add `__CPROVER_assume(p != NULL)` unless the code must handle that, or the first failure is a false alarm.
- `cbmc`, `goto-cc`, and `goto-instrument` also come with Kani, in `~/.kani/<version>/bin`.

## A test of the real code under the sanitizers

- **Make the sanitizers stop the run.** By default UndefinedBehaviorSanitizer prints a report and the program goes on, so a test passes with undefined behavior in it. Build with `-fsanitize=address,undefined -fno-sanitize-recover=all`. Look at the flags that the repo's own tests use: when they lack the last flag, those tests cannot fail on undefined behavior, which is a finding of its own.
- **Put each input in a heap block of exactly its size,** so that AddressSanitizer stops a read one byte past the end. A buffer that is larger, or a `std::vector` with spare capacity, hides it. For C++, define `_GLIBCXX_ASSERTIONS`, so that `operator[]` of the standard containers and `first` and `subspan` of `std::span` check their bounds. A raw pointer from `.data()` and an iterator stay unchecked.
- **Know what the sanitizers miss.** AddressSanitizer sees only an access outside a whole allocation. It misses a write that runs from one field of a struct into the next, and a read that runs from one element of an input into the next element of the same input. So check the outputs, such as each length against its array, and generate each element also as the last one of its input, where a read past it leaves the block.
- **Generate every input of a small shape, then random ones.** Enumerate every length and every value of the fields that the code branches on, up to a size that runs in seconds, then add seeded random inputs of every size that the code can receive. State the shapes in the record.
- **Count what ran.** Build a second time with `--coverage` and without the sanitizers, and run `gcov -b -c` on the covered files. It prints counts, not percents. An edge marked `(throw)` and a branch that a sanitizer added are not paths of the code. Each line or branch of the covered code that never ran needs an input or a reason in the record.
- **Keep the run cheap.** Build the check with `-O1`. AddressSanitizer keeps freed memory for a while, and a check that runs millions of inputs can take gigabytes: set `ASAN_OPTIONS=quarantine_size_mb=16`. It also reserves terabytes of address space, so it does not start under `ulimit -v`: cap its memory with `hard_rss_limit_mb` in `ASAN_OPTIONS`, and its time with `timeout`.
- **Make a failure readable.** Print the input that failed as hex before the program aborts, and give the check a mode that runs one input again, so that the path can be told in the code's words.
- A new test target in the build files is test code, not product code.

## The record

- Name the compiler and its version, the target that the check ran on, and the flags. A check on the host does not cover a 32-bit board, its stack, or its compiler.
- Say which claim rests on a proof and which on a test.
