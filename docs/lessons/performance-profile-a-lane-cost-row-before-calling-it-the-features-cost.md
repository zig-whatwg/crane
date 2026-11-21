# Performance: Profile a lane's cost row before calling it the feature's cost

**Date**: 2026-11-20
**Lesson**: When a cost row of a feature lane is over the bar, `sample` the two release consoles running the row's operation before writing that the feature costs it. A check the lane added beside the feature, run on every command, can be the whole cost.

**Why**: The lane's report names what the user rules on. "The undo history costs 14% on delete" would have put a ruling on the wrong code, and kept a cost no browser pays.

**What Happened**: Lane edit3 added an undo history (every editing command records its DOM changes, Blink's model). Its focused cost row editing.delete-join read time 1.142, instructions 1.147 at 8a9728eec against main 5c31228a3. The first explanation was the recording: a selection snapshot, a record and a RefHold per change, and tracing a full stack.

A `sample` on chat2 of both release consoles running the same delete-join loop (a scratch page through `repl file://...`, 15 s each) disagreed:
- main 998 us/op, tip 1167 us/op;
- undo recording was 1-2 samples in all;
- 970 of the tip's 8705 execCommand samples (~83 us/op) were visible_position.previousPositionOf.

That was the lane's other change: delete now asks whether the caret is its root's only caret position (Blink DeleteKeyPressed's MakeEditableRootEmpty check), and the previous-position walk crossed the block boundary on every Backspace at a paragraph's start.

The same measurement pass also took a retained page per row (footprint before and after `count` commands, tip minus main). It showed what the history really holds: ~2.5 KB per delete-join step (the detached tree, Blink holds it too), and ~140 B per typed character in a typing step, which coalescing adjacent insertions then removed (Gecko's InsertTextTransaction::Merge).

**Fix**:
- 569f0b542: the sole-caret check returns at once when the canonical caret is beside a non-white-space character, which is rendered, so a caret position lies on its other side.
- ddf2f7cfb: a typing step keeps adjacent typed characters as one insertion.

**Takeaway**: **An over-bar cost row is a measurement to explain, not a fact about the feature: profile both consoles on the row's operation, and size what the feature holds with a retained page, before a ruling is asked for.**
