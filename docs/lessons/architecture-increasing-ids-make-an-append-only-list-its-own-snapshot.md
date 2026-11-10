# Architecture: Increasing ids make an append-only list its own snapshot

**Date**: 2026-11-10
**Lesson**: When a spec iterates "a clone of the list" that callbacks may change while it runs, and the list only ever appends at its end, give each entry an id from an increasing counter: the clone is "every entry with an id up to the last one's now", and the walk finds its place again by id after a callback - no copy per iteration and no registered iterator.

**Why**: DOM "invoke" step 8 clones a target's event listener list for every dispatch at every path item, so that a listener added by a callback does not run and a removed one is skipped through its removed flag. Blink, WebKit and Servo copy a vector of references per dispatch (inline capacity 1, so small copies avoid the heap). Gecko copies nothing: it walks the live array with an end-limited observer iterator that the array's removals adjust (`EndLimitedRange`). Crane copied the identity of every matching listener into a heap list per inner invoke, then re-found each one with a linear scan before calling it: an allocation per dispatched target and quadratic work in the listener count.

**What Happened**: Lane lis1 (plan-v2 N5) moved the listeners into one block per target, entries 32 bytes, in spec order, appended only at the end (an event handler set again is replaced in place, keeping its id). Each listener already had a unique id from a process-wide atomic counter (for AbortSignal removal). Because a target's list is changed only on its own thread and every append takes the next id, ids increase along the list. So the clone is the last id at the start (`List.clone`), and `List.next` returns entries by value: if the entry before its cursor still has the id it visited last, the next index is the next entry; otherwise (a removal shifted the list, or the block moved when it grew) it binary-searches the first id past the last visited. Entries past the clone's last id were appended during the dispatch and are never reached; removed entries are not in the list. The spec's removed flag needs no storage.

**Fix**:
1. Assign ids at append from a counter that increases on the list's thread; never insert before an existing entry.
2. Keep an entry's id when the spec says it is the same entry (an event handler's new value), give a new id when the spec makes a new one (deactivated and activated again, removed and added again).
3. Readers get entries by value; the walk holds an index and the last id, never a pointer, and re-reads the list after every callback.
4. Pin it in unit tests with removals behind, at and ahead of the cursor, appends that reallocate the list mid-walk, and remove-then-add during the walk; and in a Crane test for the same cases through script.

**Takeaway**: **An append-only list whose entries carry increasing ids is its own snapshot: clone by remembering the last id, and find your place again by id after anything that can change it.**
