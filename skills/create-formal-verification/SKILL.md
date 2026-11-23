---
name: create-formal-verification
description: "Use when code needs more assurance than tests can give and no formal check covers it yet: races, retries, lock ordering, state machines, parsers, or unsafe code where a bug is costly. Also for requests such as \"model-check this race\", \"prove this invariant\", or \"formally verify this\"."
---

# Create a formal verification

<!-- Adapted from cursor/plugins pstack (MIT, (c) 2026 Lauren Tan). Modifications (c) 2026 Jascha Wanger (jascha.me). See LICENSE. -->

A test checks the cases that someone thought to write. Formal verification checks every case in a stated scope: every order of steps in a model, every input up to a bound, or every input. This skill finds the part of the repo where that matters most, verifies one property of it, and leaves a record in the repo that lets the next agent check a change against that property. Write that record for an agent who reads it cold, mid-change, and has never seen your work. The user must be able to trust the result and act on it without learning the verification language.

## Choose the target from the code

Answer from the codebase, and ask the user only what you cannot observe. If the user named an area or a bug, start there.

A good target is a promise the code makes, where a break harms users and tests rarely reach the case that breaks it. Choose the strongest such target in the repo, not the one that is easiest to verify.

## Let the question choose the tool

Pick the tool that answers the question at the lowest cost: a model checker, a proof assistant, an SMT-backed verifier, or another tool. Prefer a tool that runs on the real code over one that runs on a description of it, because a description can drift from the code and the real code cannot.

- **Can events happen in a bad order?** First look for a checker that runs the real code under every order of steps, such as loom or shuttle for Rust, Coyote for .NET, or Java PathFinder. Such a checker sees one process. When the order involves other processes, the disk, or the network, or when no such checker fits the language, use a model checker over a small model of the design. TLA+ is the default for that in any language.
- **Does the code behave for every input,** as with memory safety, overflow, or a data-structure invariant? Use a verifier that runs on the code. If no verifier runs on this language, say so, and test the real code with generated inputs, not a hand model of the function.
- **Must the property hold at every size,** where a bound is not enough? That can need a proof.

Prefer a tool that the repo's developers can install and run, and tell the user why you chose it.

## What makes it good

- **True to the code.** Every part of the model or proof points to code that a reviewer can open. What the verification treats as one indivisible step is one indivisible step in the code. Names come from this repo.
- **Able to fail.** A check that you have never seen fail proves nothing. Show each property failing on a broken variant of the code it guards, such as a removed check or a reordered step. A pass is also empty when the steps that matter never happen. After a pass, look at how often each step ran, and explain each step that never ran.
- **Findings stay findings.** When the current code breaks the property, report it with the counterexample in the code's terms. Do not weaken the property or the model until it passes, and do not change product code unless the user asks.
- **Honest about scope.** Say what is verified, under which bounds and assumptions, and what is left out. A pass covers the model or the bound, not the whole system. Keep two lists apart: what the verification leaves out, and what it includes and shows to break. The second list is a finding about the design, also when no change to the code can fix it.
- **Readable without the tool.** State the property and the harm in one plain sentence each. Tell a counterexample as a short sequence of steps in the code's words.
- **Cheap to rerun.** One command, a reproducible tool version, and a run short enough that the next agent will use it on every relevant change.
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

Write one entry for each covered stretch of code, with its path from the repo root. A file with two stretches far apart gets two entries. Each `> ` line cites one line of the file by a piece of its text. The first cited line is where the stretch starts, the last is where it ends, and the lines between are the steps that the verification depends on, in the order they appear in the file. Cite the text, not the line number, so that the record survives edits elsewhere in the file. The script takes the first line that contains the text after the previous cited line, so choose text that no earlier line has. An entry with no cited lines covers the whole file.

Cover the code that the verification assumes, not only the code that it follows step by step. When a step relies on a helper to be exclusive or atomic, such as the function that takes the lock or the one that replaces a file, give that helper its own entry. Keep line numbers out of the comments in the model too, and name the function there.

Then run `sh <maintain-formal-verification skill dir>/drift.sh --sync <record>` from the repo root. [`maintain-formal-verification`](../maintain-formal-verification/SKILL.md) is the skill next to this one. The script prints the line numbers of each stretch, so check that they are the lines you meant, and it writes a hash of each stretch after its path. From then on `drift.sh` reports a stretch whose text changed, and names a cited line that is missing or moved. Tell the next agent to run `--sync` again only after it confirms that the verification describes the changed code.

The record also holds:

- which code maps to which part of the verification;
- each rule, with what it promises and the harm when it breaks, in one plain sentence each;
- how to run the check, what a pass looks like, and where `drift.sh` is: in the `maintain-formal-verification` skill, run from the repo root. Say that a pass on a verification that no one updated says nothing about a change to the covered code;
- the steps for a change to the covered code, as described below;
- each deliberate break and the rules it must break;
- the known weaknesses of the design: each case that the verification includes and shows to break, how to see it, and the harm;
- what the check does not cover.

The steps for a change serve an author, and a reviewer of a change that has not landed yet. A change that landed without a recheck goes to `maintain-formal-verification`, so say that in the record. The steps are: update the verification from the code, run the check, replay a failure against the code to tell a bug from a modeling error, confirm that the check can still fail, and only then sync. The record also says these three things:

- A change that alters nothing that the verification describes, such as a rename, needs only a read against the verification and then a sync.
- When a change adds a step, a rule that names steps must name the new step too. That does not weaken the rule, as long as its plain sentence stays true.
- When a change has a bug, the updated verification stays with that change, as a patch or on its branch, and no one syncs it.

If the check is a TLA+ model, tell the next agent to run it with the [`tla-check`](../tla-check/SKILL.md) skill. It needs only Java, and it prints whether each rule holds and the shortest path to a break, with only the variables that changed at each step. For a model small enough to draw, about 500 states or fewer, the [`statechart`](../statechart/SKILL.md) skill also draws how the system moves between states; it needs a TypeScript runtime and mise. Refer to both by name, and say that they come from the `formal-proofs` plugin and which version you used, so that the next agent can find them. Their commands, options, and file paths change between releases and machines, so copy none of them into the record or its scripts.

Give the model a switch for each deliberate break that you used to show a rule failing, such as a `Faults` constant that is empty in the committed config. List each fault in the record with the rules it must break, so that the next agent can confirm in one run each that the check can still fail. Also list each step that never runs in the committed config, with the reason, such as a step behind a switch that is off. Any other step that never runs is an error in the model.

Then write a project-local skill at `.claude/skills/<name>/SKILL.md` that only points at the record. Its frontmatter names the covered files and functions and says when to use it, because without frontmatter the skill never registers. Its body is one line that tells the agent to read the record and follow it. Run `git check-ignore -q .claude/skills/<name>/SKILL.md`. If it exits 0, git ignores that file here, so say in the hand-off that the pointer stays on this machine and the record is what is shared.

## Prove it before you hand off

The author of a record cannot see its gaps, so a reader who has not seen your work must test it. Make a scratch copy of the repo outside the repo, and put two uncommitted changes in it:

- one that breaks the property in the real code;
- one refactor of covered code that changes no behavior.

When you can start a fresh agent, give it the scratch copy and the path of the record, and ask it to review the uncommitted changes. Do not tell it what the changes are or what you expect. With only the record, it must report the break, with the rule and the path in the code's words, and it must pass the refactor. If it misses the break, reports the refactor as a bug, or cannot run a step, fix the record or the verification, not the scratch changes. Then test again with a new fresh agent on a new scratch copy.

When you cannot start a fresh agent, follow the record yourself on both changes, and say in the hand-off that no cold reader tested it.

Last, delete the scratch copy, and confirm that the check in the repo is where it started: passing, or failing only on the findings you will report. A record that no one has followed is a draft.

## Hand off

Tell the user:

- what you verified, which tool you used and why, and the bounds;
- what the check found, in plain words;
- the known weaknesses of the design, apart from what the check leaves out;
- how to run the check;
- who tested the record: a fresh agent, or only you.

Say that `drift.sh` reports a change to the covered code, and that the `formal-proofs` plugin carries a hook that reminds an agent after such an edit and a GitHub Action that runs `drift.sh` and the models in CI. Offer to add the action to the repo's CI. Suggest a second target only if you found a close one. Point the user at `maintain-formal-verification` for bringing the verification back in line after changes that did not recheck it.
