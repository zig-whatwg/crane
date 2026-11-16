# Workflow: A count is a claim about its pattern - print a matching line before quoting it

**Date**: 2026-11-16
**Lesson**: A number printed by a gate script (`poison=1`, `9,877 tests passed`, `2 processes left`, `rc=0`) says what its pattern matched and over what scope, not what its label says; before a count goes into a report, print one line it matched and check what it was counted out of.

**Why**: Gate scripts are copied from lane to lane and their fields are greps. A grep counts text, and the text is often not the thing: a banner that contains the word, the check's own command line, an empty file, a cached step that printed nothing. Each of these gave lane uaf1 a number that read as a result, in one morning, in both directions - false alarms and false all-clears.

**What Happened** (lane uaf1, server1 and chat2.local):
1. `lifetimebug ... poison=1 leaks=0` in all three runs, and `leak lines 1` on both sides of the Crane step. The pattern was a case-insensitive `poison` / `leak`; the one match was the bug-finding runner's banner ("the leak-checking allocator ... poison-on-free"). Found by printing the matching line. A poison read was the very thing the lane was looking for.
2. `626/626 steps succeeded; 9877/9907 tests passed` for a native test step, where another lane's same step reported 15,273. Not a failure and not the whole suite: 52 suites ran and 77 were cache hits from an earlier job in the same mirror (`+- test tests-url cached` in the build summary). The final gate ran with `-Dlaunch-seed=random` and the script now prints `test steps: ran 129, cached 0`.
3. `pgrep -f '<pattern>' | wc -l` said 1 or 2 processes of the lane were left on a pool host, three times. Each time it was the check's own `bash -c` command line, which contains the pattern.
4. A measurement script printed `passed 0, panics 0, banner: 0` for every run: it read a journal the plain runner does not write and grepped a stdout log that was empty. The runs themselves were fine (exit 0, 200 results each).
5. A one-line regex over a wptreport labelled subtest statuses as harness statuses ("34267 PASS ... 1 TIMEOUT"); parsing the JSON showed 42 harness TIMEOUTs - all pages outside the worklist (reference pages and support frames a directory listing had put in the list).
6. `window rc=0` and a task notification's `exit code 0` are the wrapper's status: inside that window `compare rc=1` and `verify rc=1`.

**Fix**:
1. For every count you are about to quote, print the first matching line (`grep -m1`), or the list instead of the count.
2. Know the denominator: how many suites ran against how many were cached; how many list entries are tests.
3. Exclude the known non-results from the pattern (the runner's banner), and make a process pattern unable to match itself (`grep '[w]pt_runner'`).
4. Parse structured output as what it is (JSON with a JSON parser), not with a regex that drops the nesting.
5. Read each step's own status line; a chain's last status is only the last command's.
6. When a field turns out to be wrong, fix the script before it is copied again (`tmp/plans/uaf1-scripts/b1`: `window.sh`, `w-gate.sh`, `gate-pre.sh`, `qcost.sh`).

**Takeaway**: **Treat every count in a gate line as unverified until you have seen one thing it counted and know what it was counted out of. Ten seconds with `grep -m1` separates "the banner" from "a poison read", and "a cached run" from "the suite passed".**
