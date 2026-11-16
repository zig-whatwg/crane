# Workflow: A clean merge can leave a lane's new code outside a rule main just made

**Date**: 2026-11-15
**Lesson**: When main gains a rule while a lane is paused, git only shows the lines both sides edited; the lane's NEW code of the same kind merges cleanly and silently breaks the rule.

**Why**: A rule such as "a pointer is over nothing of a document that is not fully active" (lane tl1) is applied by its author at every site that existed on main: `Pointer.currentTarget`, `pointerMove`, `keyDown`. A paused lane (quick2) had added new sites of the same kind in the same file - a touch contact's elements, pointer capture targets, where a tap left the legacy mouse - and git reported one conflict, in the one function both lanes edited. Every other new site merged without a marker and compiled.

**What Happened**: After merging main into lane/quick2, the conflict in `pointerMove` was a one-line hand merge, and the merge instructions said so. Reading tl1's change for what it MEANT, and then listing every weak reference quick2 had added to `user_input.zig`, showed three page-visible bugs that no existing test caught: a touch whose frame was removed stayed an active pointer of the tab, so the next touch was not primary and its tap made no click; a mouse captured in a frame that then navigated stayed captured by the old element, so the live page got no mouse events; a tap's mouseover named the gone document's element as its relatedTarget. All three failed in new tests on the merged tree before any fix.

**Fix**:
1. After merging, read each merged lane's report for the RULE it established, not only for the API it changed.
2. List the lane's own additions of the kind the rule covers (here: every `Weak` field and capture `Ref` the lane added) and check each against the rule.
3. Write the failing test on the merged tree first; then apply the rule through one helper (`inFullyActiveDocument`) so the next site has one thing to call.
4. A test that cannot fail is not a red test: no listener runs at an element of a document that is not fully active, so "no event was heard there" passed before the fix. Assert what the page can see (isPrimary, the pointer's current target, relatedTarget), and say in the test file which tests were red.

**Takeaway**: **A merge without conflicts is not a merge without work: for every rule main gained, check the code only your branch has.**
