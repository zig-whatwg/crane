# Workflow: Read the browsers' failure messages, not only their pass counts

**Date**: 2026-10-18
**Lesson**: wpt.fyi keeps every run's per-test results, messages included, at a plain URL; two browsers failing a test with exactly Crane's message is evidence that Crane already does what they do - and often what the spec says.

**Why**: Golden rule 2 needs to know what the browsers DO, and a pass count says only that they fail. navigation-api/ordering-and-transition/currententrychange-before-popstate-intercept.html fails in Chrome 155 and Firefox 158 and passes only in Safari 27. Reading the spec showed why: "update the navigation API entries for a same-document navigation" step 15 ("clean up after running script") performs a microtask checkpoint in the traversal's task before popstate fires, so `finished` settles first and the test's assertion that popstate already fired fails. Chrome and Firefox fail it with "assert_true: expected true got false" - Crane's exact message. Without the messages the file looked like a Crane bug to fix toward Safari.

**What Happened**: lane nav1 was briefed to make the file pass. The per-test JSON of the latest stable runs showed the same failure in Chrome and Firefox, so the file was left as it is, stated (spec + 2 of 3 browsers).

**Fix**: fetch a test's result per browser:

```bash
# run ids and their results directory: https://wpt.fyi/api/runs?label=master&label=stable&products=chrome,firefox,safari&max-count=1
# then https://wpt.fyi/api/runs/<id> gives results_url .../wptd/<full sha>/<run dir>-summary_v2.json.gz
curl -s "https://storage.googleapis.com/wptd/<full sha>/<run dir>/<test path>"   # status, message per subtest
```

e.g. `<run dir>` = `chrome-155.0.8059.84-linux-22.04-fadd451b21`. The summary API (`/api/search?run_ids=...&q=...`) gives counts only.

**Takeaway**: **Before fixing a file toward the one browser that passes it, read the other two's failure messages: if they fail the way you do, you may already match the spec they implement.**
