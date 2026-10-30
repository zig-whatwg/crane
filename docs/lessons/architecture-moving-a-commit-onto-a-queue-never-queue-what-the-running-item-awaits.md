# Architecture: Moving a commit onto a queue - never queue what the running item awaits, and hold readers before the write

**Date**: 2026-10-30
**Lesson**: When a step that ran inline becomes an item of a one-at-a-time queue, three things break unless checked: a call path the running item itself waits on must stay inline (or it deadlocks); readers that must not see the change are held BEFORE the write, not after; and every number the step computes is re-read from the spec, not carried over from the inline code.

**Why**: Lane nav2 F1 made "finalize a cross-document navigation" an item of the traversable's session history traversal queue (an apply of kind .push_replace whose change job is the rest of HTMLIFrameElement's runCommit). runCommit served three callers: a navigation's commit, a traversal's population, and a reload's population - the last two being the change jobs of the apply that is RUNNING on that same queue.

**What Happened**: Three defects, each caught by a different gate:
1. The first draft handed every runCommit to the queue. A cross-document traversal's population appended a .push_replace item behind the traversal that waited for that population: 22 native tests timed out (`never true: location.href === ...`) - every cross-document back(), go() and reload in tests/html. Fix: only a navigation (no traversal entry) is handed over; a population commits inline, inside its apply's job, as before.
2. The listing (JointHistory.listCrossDocument) ends a history change, which rewrites every view; the apply's holdAllViews ran AFTER it, so the held views already showed the new entry and the leaving document's pageswap, pagehide and unload read the new history.length (nav2_unload_views_test). Fix: hold every view first, then list (and release on the failure path).
3. For a replace, the draft applied the replaced entry's step; the spec's step 9.4 is "set targetStep to traversable's current session history step". A frame's first entry sits at the step its parent's document began at, so a frame's initial replace set the WHOLE PAGE's current step back at the apply's step 20. The claimed-file probe lost history_forward_cross_realm_method (the page's back() and the frame's srcdoc commit interleave on the queue); the unit test had pinned the wrong step.

**Fix**:
1. Before queueing a step, list every caller of the code path and ask of each: is it already running inside an item of this queue? Those stay inline.
2. Hold readers (views) before any write they must not see; the write's own change bracket may publish it.
3. Re-derive each computed value (here targetStep) from the spec text for each branch (push and replace differ), and pin it in a unit test that would fail on the inline code's value.
4. Run the claimed-file probe before the full A/B: it caught (3) in 10 minutes.

**Takeaway**: **A path the running queue item waits on can never be queued behind it; hold readers before the write; recompute every value a moved step derives from the spec's own branch text.**
