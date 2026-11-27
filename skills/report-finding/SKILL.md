---
name: report-finding
description: "Use when a finding of a formal check (a model, a proof, or a harness with a VERIFY.md record) is to go to the project's maintainers, as a report, an issue, a pull request, an advisory, or an email."
---

# Report a finding

A check of an old checkout, of one path, or of a model can find a bug that the project does not have: it is fixed already, or other code keeps the rule. A security bug in a public place tells attackers about it before there is a fix. Check each finding first, and then let the user decide where it goes.

## Check each finding

- **Replay it on the latest code.** In a scratch clone, get the newest default branch and the newest release of each release line that the project still ships, and replay each finding on them. Drop a finding that no longer breaks, and say that it is fixed there. When the newer code rewrote what the check covered, port the finding's small test (below), not the whole verification, and say so. For each version, say whether a test showed the bug, or only a reading of the code. When the covered files are the same in a version, shown by `git diff --quiet A B -- FILES`, the replay holds for that version too: say that the files are the same. When you may not reach the remote, replay on the newest branch and tag that the clone has, and say that newer code was not checked.
- **Look for other code that keeps the same rule.** Before you call a broken rule a bug or say how bad it is, search for every other place that enforces it, such as a second listener, a periodic scan, or a check on the server. Confirm that such code runs in the case that breaks: a scan can look up the wrong key and find nothing. Say which cases still break, and rate the finding by those.
- **Give each finding a test of its own.** Write the smallest test that shows the bug on the real code, without the model or the harness, so that a maintainer can run it on their own branch. It fails now and passes after a fix. Name the versions where you ran it. This is a second test next to the one that the record keeps: the record's test passes while the bug is there, and lives in the repo. This one fails now, needs only the project's own test setup, and lives next to the report.
- **One report for what one fix closes.** Put findings that one fix would close into one report, and a finding with another fix or another route, such as a security bug, into a report of its own. A weakness of the design that breaks no promise of the project is a note in the report, not a finding.

## Keep a security bug private

When a finding lets someone get around a security rule, such as access that stays after it was revoked, read the project's security policy, often `SECURITY.md`, with every document that it points to, and follow its private route, such as an advisory form or an email address. When the project has no policy, say so, and advise a private route to its owner. When two documents name different routes, say so. A repo that holds the policy can take private advisories of its own: check it with `gh api repos/OWNER/REPO/private-vulnerability-reporting`.

Never put such a finding in a public issue, pull request, or commit message. In a public repo, the record and the configs of the finding disclose it too: ask the user before they are committed or pushed. When the user asks for a public route, say first what the policy asks for.

## Ask before you send

Write each report as a file outside the repo, so that it is not committed by mistake. Do not open an issue or a pull request, send an email, or file an advisory, unless the user asked for that action in this task or in standing instructions. A request to report the finding that names no route asks for the report, not for an action: write it and ask.

Tell the user:

- what the finding is, in plain words, and on which versions it still breaks;
- the route that the project's policy names, and any other route that a document of the project names;
- where each report is, with the question what to do with it: send it, change it, or hold it.
