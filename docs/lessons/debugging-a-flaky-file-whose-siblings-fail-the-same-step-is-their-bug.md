# Debugging: A flaky file whose siblings fail the same step deterministically is their bug

**Date**: 2026-11-23
**Lesson**: Before chasing a flaky file's timing, read every sibling file's result: when the files that share its harness fail deterministically at the step the flaky one depends on, that is one bug, and the flake is the race it opens.

**Why**: Files built on one support script share one algorithm. A defect early in it lands differently by what each file expects: a file expecting the other outcome fails every time, while a file expecting the defect's own outcome passes or fails on whatever later race the defect leaves open. Read alone, the second kind looks like a timing problem.

**What Happened**: Lane flk4 item 9: html/semantics/embedded-content/media-elements/track/track-element/cors/035.html failed 5-6 of 10 runs and 037.html 9-10 of 10, on both runners. Both expect an `error` event and then read the requests the server logged. In the same directory, every file that expects `load` (003-008, 014-019, 022 and more) failed every time with "expected load got error". The cause was shared: support/common.js sets `track.track.mode = 'showing'` and then `track.src` in one script. Crane's track processing model treated that src change as step 10's "URL changed while fetching" and queued an error before any request existed; the real fetch started only after the error. The load files saw `error` first. The error files raced their XHR stash read against the late fetch's requests: the flake. HTML 4.8.11.11.3 aborts only "while fetching is ongoing", and all three browsers run the deferred steps after the task (Chrome a zero-delay timer, Safari a media element task, Firefox RunInStableState after the task), so a src set in the same script is simply the URL they fetch.

**Fix**:
1. List the whole directory's results, not only the flaky file's: `cat <run>/*wptreport*.jsonl` filtered to the directory, each file's subtest statuses and first failure message.
2. Group the files by the step their failure names. A deterministic group whose message is the flaky file's precondition is the lead.
3. Reproduce it with a Crane test that fails every time (tests/wpt/crane/flk4-track-src-after-mode.html: 5/5 red on main's runner), fix that, then A/B the directory: the flaky files become deterministic, and the deterministic ones move.

**Takeaway**: **A flake in a directory of siblings is evidence about their shared harness: a sibling that fails the same step every time is the deterministic face of the same bug - fix that one and the flake goes with it.**
