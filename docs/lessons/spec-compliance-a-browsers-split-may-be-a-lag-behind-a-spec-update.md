# Spec Compliance: A browsers split may be a lag behind a spec update

**Date**: 2026-11-14
**Lesson**: Before following a two-browser majority against the spec text, find out whether the spec text is an update that the third browser already ships.

**Why**: Golden rule 2 has two different cases. When no newer spec is involved, a split follows the majority. When the spec was updated and one of Chrome, Firefox and Safari ships the newer text, Crane implements the newer spec, even against the other two. The wpt.fyi counts look the same in both cases. Only the spec's history tells them apart.

**What Happened**: History.go() left out the sandbox check on delta traversals ("apply the history step" step 3, initiatorToCheck) as a stated "browsers split" deviation: Firefox and Safari let a sandboxed frame's history.back() move its parent's entries, and only Chrome refused. Two files blocked the 0.1 gate for it (iframe_sandbox_navigate_history_go_back.html and _go_forward.html). The check was in fact a spec update: whatwg/html PR #4787 (merged 2019-08-13) added it, a Chromium engineer wrote it with the tests (Chromium bug 705583), and Chrome shipped it after an Intent to Ship. No Mozilla or WebKit objection, WontFix bug or negative standards position existed: the other two lag.

**Fix**: Lane ifr1 passed the initiator to the delta traversal (`initiatorOf`, as the navigation API's traversals already did) and replaced the deviation comment with the spec change's evidence.

**Takeaway**: **A "browsers split" reading must check the spec's history first: the commit history of the WPT test (its commit message usually names the spec PR) and the spec PR's implementation bugs say whether the minority browser is ahead, not out-voted.**
