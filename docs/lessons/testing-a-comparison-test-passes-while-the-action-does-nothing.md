# Testing: A comparison test passes while the action it compares does nothing

**Date**: 2026-11-12
**Lesson**: A WPT file that compares two cases of one user action - "Ctrl+Backspace after `<span>def</span>` should give the same innerText as after `def`" - passes while the action does nothing in both; turning the action on for the easy case alone breaks it.

**Why**: The gate counts PASS, and a comparison of two no-ops is equal. So is "selectstart shouldn't be fired because the selection is still collapsed" while Shift+Arrow moves nothing. These passes are vacuous, and nothing marks them as such in the journal: they sit in the generation's PASS set like any other.

**What Happened**: Lane editing5 batch 3 routed the word modifier with Backspace/Delete to a word deletion built on Selection.modify("extend", ..., "word"), to unblock editing/whitespaces/delete-last-word-in-inline-block-editing-host.html. Selection.modify's word steps stop at a Text node's edge, so `abc def[] ghi` deleted "def" while `abc <span>def</span>[] ghi` deleted nothing: delete-word-around-span.html and forwarddelete-word-around-span.html lost 16 subtests (4 variants x 2, twice) that generation 216 passed only because neither case did anything. In the same area run Shift+ArrowLeft/Right started extending the selection without a selectstart: selection/onselectstart-on-key-in-contenteditable.html lost 4 that had passed because the selection stayed collapsed.

**Fix**: The selectstart was a missing step (Blink's FrameSelection::Modify dispatches it before extending a caret): added. The word deletion was reverted to a TODO until word movement crosses inline boundaries - one file unblocked was not worth 16 subtests lost, and never-trade-passing-subtests forbids it anyway.

**Takeaway**: **Before turning on a user action that did nothing, grep the worklist for every file that presses it and read which of their subtests the generation passes: a comparison or "should not happen" subtest that passes today is a contract the new behaviour must meet in every case it compares - complete the action for all of them, or leave it off.**
