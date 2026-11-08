# Spec Compliance: A removing step applied lazily misses a re-insertion

**Date**: 2026-11-07
**Lesson**: A state change the spec makes at a node's removal cannot be deferred to the next read of the state: a node removed and inserted again before that read looks as if it was never removed.

**Why**: HTML's removing steps step 2 sets the document's focused area to the viewport when the focused element is removed. Crane applied it lazily - `focusedAreaOf` treated a designated element that was no longer connected as removed. That answers correctly only while the element stays out of the document.

**What Happened**: dom/nodes/moveBefore/fire-focusin-focusout.html passed 1 of 5: each test's cleanup re-inserted the focused button with `append` (a removal and an insertion), so the next test's `button.focus()` found it still focused and fired no focusin. Document.zig's comment said the lazy rule "fires no event, so activeElement reads the same either way" - true for a removal, false for a removal followed by an insertion. With moveBefore implemented as DOM "move" (no removing steps), the difference between a move (focus kept) and a re-insertion (focus lost) has to be a real state change at the removal.

**Fix**: `html.focus.removingSteps`, registered by Document's installHooks: at the removal's root, if the designated element is in the removed subtree, designate the viewport and clear the navigation API's focus-changed flag (no event). The lazy check stays as the net for a freed or adopted element. tests/html/move1_focus_removal_test.zig removes and re-inserts the focused element before any read.

**Takeaway**: **A removal's state change happens at the removal; a lazy check at the next read is only a net, because the node can come back before anyone reads.**
