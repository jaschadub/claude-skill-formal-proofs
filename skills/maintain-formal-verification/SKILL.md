---
name: maintain-formal-verification
description: "Use when code that a formal model, proof, or verifier covers has changed without the verification being rechecked: after merges or refactors, when drift.sh or a hook reports that verified code no longer matches its VERIFY.md record, or when asked \"is the model still true to the code\"."
---

# Maintain a formal verification

<!-- Adapted from cursor/plugins pstack (MIT, (c) 2026 Lauren Tan). Modifications (c) 2026 Jascha Wanger (jascha.me). See LICENSE. -->

A formal check proves a property of what it describes. When the code changes and the verification does not, the check can keep passing while it describes code that no longer exists. That pass is the dangerous case, because it looks like a proof. This skill is the upkeep loop for a record (`VERIFY.md`) that `create-formal-verification` wrote, or for any project-local skill (in `.claude/skills/` or a plugin's `skills/`) that runs a model checker, prover, or code-level verifier against named code. The record handles a change that an agent makes while it follows that record. This skill handles the changes that skipped it: merges, edits made without the record, and drift that builds up across many commits.

## Outcomes

Give each check one outcome, and say which:

- **in sync**: no change since the last sync alters what the check describes, and the check passes.
- **updated**: the code changed, the verification now describes the new code, and the check passes.
- **bug**: the verification describes the current code, and the code breaks the property. This is a finding about the code. It is not drift.
- **blocked**: the check could not be brought back in line or could not run. Say exactly why.

A check can be both updated and bug: the update makes the verification describe the code again, and then the property fails on it.

## Edit scope

Edit only the verification: models, harnesses, property files, and the record itself. Never edit product code during a run, unless the user asks you to. When a property fails on the current code, do not weaken the property or the model to make it pass. Report the failure.

## Pass

1. **Find the checks.** Run `sh <skill dir>/drift.sh` from the repo root. It finds each `VERIFY.md` in the repo, and exits 2 when there is none. Then also look for a check with no record: a project skill that runs a model checker, a prover, or another verifier against named code. Read each one you find, or the one the user named. For each check, collect the property, the code it covers, the bounds and assumptions, the command that runs it, and when it was last confirmed to describe the code. If no check exists, stop and point at `create-formal-verification`. For a check with no record, use the last commit that changed the verification files as the last sync, and say that you did.

2. **Run it as it is.** Run each check once before you change anything, and record the result. A pass here does not tell you that the code is correct. It tells you that the old description still holds. A failure here can be drift or a bug. Do not decide which until step 5. When the record has a trace check, run it too: the first event that the model cannot take is where the code left the model.

3. **Read every change to covered code.** The output of `drift.sh` names each covered stretch of code whose text changed since the last sync, or the first cited line of a stretch that is missing or moved. Later lines of that stretch can be missing too. Under each one it lists the commits and uncommitted changes that touched the file since that sync. It takes the sync from the commit that put the stretch's hash into the record, so after a later sync that left the hash as it was, the list can hold commits that someone has read already. It exits 1 when there are any. A stretch that it does not name did not change. For a check with no record, do the same by hand: diff the covered files from the last sync to the current commit. Read each diff and each commit message. Also look for code that moved: a covered function that is renamed, split, or moved to another file is still covered code. Also look for new code that touches the state that a check guards, such as a new function that writes the same fields; `drift.sh` cannot see it. For each change, decide which of these it is:
   - **No effect.** The change does not alter anything the verification describes, such as formatting, comments, or code paths that the verification does not cover. Check this against the model or harness, not against the commit message.
   - **The verification no longer describes the code.** A step that was one indivisible action is now two, a branch was added or removed, a check moved, a new path reaches the guarded state, or a value now has a different range. The model or harness must change.
   - **The promise changed on purpose.** The change alters what the code promises, and evidence in the change says that this is intended: the doc comment, the tests, the changelog, or the commit message. The property must change, and you must cite that evidence.
   - **The promise may be broken.** The code changed, and no evidence says that the promise changed. Treat a failure that follows as a bug candidate.

4. **Update from the code, not from the result.** Change the model or harness so that each changed part again points to code that a reviewer can open, and keep one indivisible step in the code as one step in the verification. Write the update from the code before you rerun, and do not shape it by what makes the check pass. Change a property only for a promise that changed on purpose. Write down the old wording, the new wording, and the evidence. A rule that names steps must name a new step too; that does not change the promise, as long as its plain sentence stays true, but say in the report that you did it. Keep the bounds unless the change makes them wrong. If you must reduce a bound, say so in the report.

5. **Rerun and judge each result.**
   - **Pass:** the check can now pass on a description that has lost the ability to fail. Break the new code the way the property guards against, such as removing a new check or reordering a new step, and confirm that the check catches it. Then drop the break. Also confirm that the pass is not empty: look at how often each step ran, and explain each step that never ran.
   - **Fail:** replay the counterexample against the real code, step by step. If a step cannot happen in the code, the verification is wrong. Fix the verification, and say what was wrong. If every step can happen, it is a bug. Name the commit that introduced it, or say that the change is not committed, tell the counterexample as a sequence of steps in the code's own words, and state the harm in one sentence. If a cheap test or reproduction against the real code shows the bug, add it to the report as evidence. Do not commit it to the product code.

6. **Update the record.** Update the code that each check covers, the commands, the bounds, and the assumptions. In the `covered:` block, update each cited line that moved or changed, and cite each new step that the verification now depends on. A check with no record gets one: write `VERIFY.md` next to the verification, as `create-formal-verification` describes. Then run `sh <skill dir>/drift.sh --sync <record>`, check that the line numbers it prints are the stretches you meant, and commit the record with the verification when your instructions let you commit. When they do not, leave both uncommitted on the branch that you found, and say so. Do not sync a blocked check or a check with an open bug, and say so in the report. Then follow the record once as the next agent would, so that you know its steps still run.

## Report

Tell the user, for each check:

- the outcome, and the commits that you read;
- what changed in the verification and why, with a short reason for each change: the code changed shape, or the promise changed on purpose (with the evidence);
- the rerun result, and the break that you used to show the updated check can still fail;
- each bug, in plain words: the counterexample as steps in the code's words, the harm, and the commit that introduced it;
- what the verification still does not cover, including new code that it should cover and does not;
- apart from that, each known weakness of the design: a case that the verification includes and shows to break.

Before a bug goes to the project's maintainers, follow the [`report-finding`](../report-finding/SKILL.md) skill.

Say outright which failures were drift in the verification and which were bugs in the code. For a check that passed before you updated it and fails after, say that the old pass was on a stale description.

Put the verification updates in a change of their own, separate from any product fix.
