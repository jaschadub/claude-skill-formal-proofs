---
name: create-formal-verification
description: "Use when code needs more assurance than tests can give and no formal check covers it yet: races, retries, lock ordering, state machines, parsers, or unsafe code where a bug is costly. Also for requests such as \"model-check this race\", \"prove this invariant\", \"formally verify this\", or \"what else should we verify\"."
---

# Create a formal verification

<!-- Adapted from cursor/plugins pstack (MIT, (c) 2026 Lauren Tan). Modifications (c) 2026 Jascha Wanger (jascha.me). See LICENSE. -->

A test checks the cases that someone thought to write. Formal verification checks every case in a stated scope: every order of steps in a model, every input up to a bound, or every input. This skill finds the part of the repo where that matters most, verifies one property of it, and leaves a record in the repo that lets the next agent check a change against that property. Write that record for an agent who reads it cold, mid-change, and has never seen your work. The user must be able to trust the result and act on it without learning the verification language.

## Choose the target from the code

Answer from the codebase, and ask the user only what you cannot observe. If the user named an area or a bug, start there.

First find out how current the checkout is. When it has a remote, fetch it, and for a fork also the project that it was forked from (`gh repo view --json parent`), and count the commits on their default branch that the checkout does not have. When it is behind, tell the user how far, and ask whether to verify the checkout or the latest code. Work on old code can find bugs that are already fixed.

Then read each `VERIFY.md` in the repo. A rule that a record covers already is not a target. A new path to the state that a model covers, such as a second caller of the same lock or another writer of the same field, goes into that model as new steps, and its code into that record: two models of one state drift apart, and neither shows how the paths interleave. A target on other state gets a record of its own, in a folder of its own.

When you add a path to a model:

- Check each old step against the new path. What was one step can be two, once another path can come between its parts.
- When the new path changes on purpose what an old rule promises, as a reset does to a count, restate the rule, and write down the old wording, the new wording, and the evidence.
- Rerun every check and every fault of the record, and give the new steps a fault of their own. When a new step is itself the break, its fault goes on top of the fix.
- Treat a rule that the new path breaks as any other finding of this skill: keep it in a config of its own, and sync the record. The record's rule that a change with a bug is not synced is for a change that has not landed.

A good target is a promise the code makes, where a break harms users and tests rarely reach the case that breaks it. Choose the strongest such target in the repo, not the one that is easiest to verify.

Before you build anything, check the target against the tests. Find the test that comes closest to the promise, and name what it asserts and the case that it does not reach, such as "the bank accepted the charge, but the confirmation timed out". When no test comes close, say that. When you cannot name a case that the tests miss, the tests may already cover the promise: say so, and choose another target unless the user named this one.

## Let the question choose the tool

Pick the tool that answers the question at the lowest cost: a model checker, a proof assistant, an SMT-backed verifier, or another tool. Prefer a tool that runs on the real code over one that runs on a description of it, because a description can drift from the code and the real code cannot.

- **Can events happen in a bad order?** First look for a checker that runs the real code under every order of steps, such as loom for Rust, Coyote for .NET, or Java PathFinder. Some of these try random orders and not every order: say which yours does. Trust a checker that you have not used before only after it catches a fault that you seed. Such a checker sees one process. When the order involves other processes, the disk, or the network, or when no such checker fits the language, use a model checker over a small model of the design. TLA+ is the default for that in any language.
- **Does the code behave for every input,** as with memory safety, overflow, or a data-structure invariant? Use a verifier that runs on the code. If no verifier runs on this language, or none can read this code or finish on it, say so, and test the real code with generated inputs, not a hand model of the function. When a verifier finishes only for small inputs or for part of the code, keep it for that part, test the rest with generated inputs, and say which claim rests on the proof and which on the test.
- **Must the property hold at every size,** where a bound is not enough? That needs a proof, and a prover wants contracts written into the product code, or works on a restated copy of it. Do not start there. First run the bounded check on the real code, and say plainly that it is not a proof for every size. Give the reason why larger sizes behave the same as an argument that a reviewer can read. Put it in the record, and say there that no tool checked it. Offer the proof as a next step that needs the user's consent.

Prefer a tool that the repo's developers can install and run, and tell the user why you chose it.

When the code is Rust, read [rust.md](rust.md) before you choose. When it is Python, read [python.md](python.md). When it is PHP, read [php.md](php.md). When it is C or C++, read [c-cpp.md](c-cpp.md). When it is Go, read [go.md](go.md). Each says which checker answers which question, what a pass means, and where a model of code in that language goes wrong.

## What makes it good

- **True to the code.** Every part of the model or proof points to code that a reviewer can open. What the verification treats as one indivisible step is one indivisible step in the code. A read of a value that no other process writes can be part of the step after it: say so where you do it. Names come from this repo.
- **Able to fail.** A check that you have never seen fail proves nothing. Show each property failing on a broken variant of the code it guards, such as a removed check or a reordered step. A pass is also empty when the steps that matter never happen. After a pass, look at how often each step ran, and explain each step that never ran. For a test, that is the coverage of lines and branches of the covered code. A rule that the code breaks needs the opposite test: show that it holds on a variant with the fix, such as a model with a `Fixes` switch next to `Faults`. A rule that fails there too is one that no code can keep. Show that the check of a rule that the code breaks can fail in the config with the fix, because only there does the rule hold.
- **Findings stay findings.** When the current code breaks the property, report it with the counterexample in the code's terms. Do not weaken the property or the model until it passes, and do not change product code unless the user asks. Keep a rule that the code breaks in a config or a test of its own, so that the committed check still passes and the finding can be run again. When the code keeps a rule only because every caller meets a condition, check the rule with that condition, cover the callers' guard in the record, and report the function without the condition as a finding.
- **Honest about scope.** Say what is verified, under which bounds and assumptions, and what is left out. A pass covers the model or the bound, not the whole system. Keep two lists apart: what the verification leaves out, and what it includes and shows to break. The second list is a finding about the design, also when no change to the code can fix it.
- **Readable without the tool.** State the property and the harm in one plain sentence each. Tell a counterexample as a short sequence of steps in the code's words.
- **Cheap to rerun.** Few commands, each named in the record, a reproducible tool version, and a run short enough that the next agent will use it on every relevant change.
- **Kept in step with the code.** Record the lines of code that each check depends on, so that a script can tell when they change. Then the next agent, a hook, and CI can all see that the verification needs another look.

## Write the record

Write the record as `VERIFY.md` in the folder that holds the model, proof, or harness, so that it is committed with them. Do not keep it only in `.claude/`: many setups never commit that folder, and other agents do not read it. From the record alone, the next agent must be able to tell whether a change touches the verified code, run the check, tell a real bug from a modeling error, and update the verification when a change is intended. Use this repo's real commands, paths, and nouns, and leave no placeholders.

Put the covered code in the record as one fenced block in exactly this shape:

```
covered:
  - src/session.rs
    > async fn refresh(
    > let _guard = session_lock(
    > store.update(
  - src/store.rs
    > pub fn update(
    > fs::rename(
```

Write one entry for each covered stretch of code, with its path from the repo root. A file with two stretches far apart gets two entries. Each `> ` line cites one line of the file by a piece of its text. The first cited line is where the stretch starts, the last is where it ends, and the lines between are the steps that the verification depends on, in the order they appear in the file. Cite the text, not the line number, so that the record survives edits elsewhere in the file. The script takes the first line that contains the text after the previous cited line, so choose text that no later line of the file has. When a cited line changes, the script would otherwise take the same text further down, and report the wrong line as missing. When a step's line repeats further down, such as one call that two functions make, cite a line next to it instead: the hash of the stretch still covers the step. An entry with no cited lines covers the whole file.

Cover the code that the verification assumes, not only the code that it follows step by step. When a step relies on a helper to be exclusive or atomic, such as the function that takes the lock or the one that replaces a file, give that helper its own entry. Keep line numbers out of the comments in the model too, and name the function there.

Then run `sh <maintain-formal-verification skill dir>/drift.sh --sync <record>` from the repo root. [`maintain-formal-verification`](../maintain-formal-verification/SKILL.md) is the skill next to this one. The script prints the line numbers of each stretch, so check that they are the lines you meant, and it writes a hash of each stretch after its path. From then on `drift.sh` reports a stretch whose text changed, and names a cited line that is missing or moved. Tell the next agent to run `--sync` again only after it confirms that the verification describes the changed code.

The record also holds:

- why this target: the closest test, what it asserts, and the case that it does not reach;
- which code maps to which part of the verification;
- each rule, with what it promises and the harm when it breaks, in one plain sentence each;
- how to run the check, what a pass looks like, and where `drift.sh` is: in the `maintain-formal-verification` skill of the `formal-proofs` plugin, with the version that you used (from the plugin's `package.json`), run from the repo root. Say that a pass on a verification that no one updated says nothing about a change to the covered code;
- the steps for a change to the covered code, as described below;
- each deliberate break and the rules it must break;
- the known weaknesses of the design: each case that the verification includes and shows to break, how to see it, and the harm;
- what the check does not cover.

The steps for a change serve an author, and a reviewer of a change that has not landed yet. A change that landed without a recheck goes to `maintain-formal-verification`, so say that in the record. The steps are: update the verification from the code, run the check, replay a failure against the code to tell a bug from a modeling error, confirm that the check can still fail, and only then sync. The record also says these three things:

- A change that alters nothing that the verification describes, such as a rename, needs a read against the verification, the new text for each line that the record cites and the change reworded, and then a sync. The sync refuses while a cited line is missing.
- When a change adds a step, a rule that names steps must name the new step too. That does not weaken the rule, as long as its plain sentence stays true.
- When a change has a bug, the updated verification stays with that change, as a patch or on its branch, and no one syncs it.

If the check is a TLA+ model, tell the next agent to run it with the [`tla-check`](../tla-check/SKILL.md) skill. It needs only Java, and it prints whether each rule holds and the shortest path to a break, with only the variables that changed at each step. For a model small enough to draw, about 500 states or fewer, the [`statechart`](../statechart/SKILL.md) skill also draws how the system moves between states; it needs a TypeScript runtime. When a test can run the covered code, also add a trace check, as `tla-check` describes: the code logs each step of a real run, and TLC checks that the model can take the same steps. That ties the model to the code by more than a hash, so put its command in the record next to the check. Refer to these skills by name, and say that they come from the `formal-proofs` plugin and which version you used, from `package.json` in the root folder of the plugin, so that the next agent can find them. Their commands, options, and file paths change between releases and machines, so copy none of them into the record or its scripts. A command of the repo itself, such as the test that writes a trace log, goes into the record in full.

Give the model a switch for each deliberate break that you used to show a rule failing: a `Faults` constant that is `{}` in the committed config. `tla-check` and the CI action switch a fault on by that name. A check that runs the real code has no such switch: keep each break as a patch file next to the record, and list it with the test that must fail. Keep a fix that shows that a broken rule can hold as a patch too, and make the break of that rule on top of the fix. Make a patch in a scratch copy of the files as they are now, committed or not: commit them there first, then make the break, and take the patch with `git diff --src-prefix=a/ --dst-prefix=b/`. The two prefixes keep the patch the same under every git config. Apply a patch in a scratch copy, never in the working tree. List each fault in the record with the rules it must break, so that the next agent can confirm in one run each that the check can still fail. Also list each step that never runs in the committed config, with the reason, such as a step behind a switch that is off. Any other step that never runs is an error in the model.

Then write a project-local skill that only points at the record. Put it where your agent reads project skills: `.claude/skills/<name>/SKILL.md` for Claude Code, and `.agents/skills/<name>/SKILL.md` for Codex, Pi, and most other agents. Write the one for the agent that you are, and the other one too when the repo already has its folder. Its frontmatter names the covered files and functions and says when to use it, because without frontmatter the skill never registers. Its body is one line that tells the agent to read the record and follow it. Run `git check-ignore -q` on that file. If it exits 0, git ignores the file here, so say in the hand-off that the pointer stays on this machine and the record is what is shared. The same holds when the user's or the repo's rules say not to commit such folders.

## Prove it before you hand off

The author of a record cannot see its gaps, so a reader who has not seen your work must test it. Make a scratch copy of the repo outside the repo. It must hold your record and verification, also when they are not committed yet, so a new worktree or clone alone is not enough. Leave out what git ignores, such as build output: it is large, and a stale build can run in place of a change. Put two uncommitted changes in the copy:

- one that breaks the property in the real code;
- one refactor of covered code that changes no behavior.

When the checks cannot pass while the break is in place, put the refactor in a second copy. Before you judge the record by the break, confirm on the copy that it really breaks the property, with a test or a replay: a change that looks like a break can change nothing.

When you can start a fresh agent, give it the scratch copy and the path of the record, and ask it to review the uncommitted changes. Do not tell it what the changes are or what you expect. With only the record, it must report the break, with the rule and the path in the code's words, and it must pass the refactor: the checks pass, each finding can still be replayed, and the reader gets through the steps of the record to the sync. If it misses the break, reports the refactor as a bug, or cannot run a step, fix the record or the verification, not the scratch changes. Then test again with a new fresh agent on a new scratch copy.

When you cannot start a fresh agent, follow the record yourself on both changes, and say in the hand-off that no cold reader tested it.

Last, delete the scratch copy, and confirm that the check in the repo is where it started: passing, or failing only on the findings you will report. A record that no one has followed is a draft.

## Check each finding before you report it

Before you hand off a finding, follow the [`report-finding`](../report-finding/SKILL.md) skill. It replays the finding on the latest code, looks for other code that keeps the rule, gives the finding a test of its own, keeps a security bug private, and asks the user before anything is sent.

## Hand off

Tell the user:

- what you verified, the case that the tests do not reach, which tool you used and why, and the bounds. When the user asked for a formal verification and you deliver a test, say so first, and say what a proof would take;
- what the check found, in plain words, and on which versions it still breaks;
- where each report is, with the question what to do with it;
- each rule in one plain sentence, with the question whether that is what the system must always do. You chose the rules from the code, and only the user can say that they are the right ones. A rule that the user rejects is a wrong specification, however well it is checked;
- the known weaknesses of the design, apart from what the check leaves out;
- how to run the check;
- who tested the record: a fresh agent, or only you.

Say that `drift.sh` reports a change to the covered code, and that the `formal-proofs` plugin carries a hook that reminds an agent after such an edit and a GitHub Action that runs `drift.sh` and the TLA+ checks in CI. Offer to add the action to the repo's CI. A check that is not a TLA+ model, such as a Kani or a loom run, needs a CI step of its own: say so, and offer to add that too. So does a config other than the one next to its spec, such as the one with a fix or with a finding: the action runs each spec only with the config next to it. List the other targets that you considered, strongest first, each with its promise, the harm of a break, and the record that covers it already or "not covered". Point the user at `maintain-formal-verification` for bringing the verification back in line after changes that did not recheck it.
