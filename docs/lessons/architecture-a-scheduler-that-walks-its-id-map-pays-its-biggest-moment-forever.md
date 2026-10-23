# Architecture: A scheduler that walks its id map pays for its biggest moment forever

**Date**: 2026-10-23
**Lesson**: A queue asked "what is due next?" on every turn needs an order of its own: a min-heap that stores each entry's index, beside the id map. If it walks the id map, it walks the map's capacity, and that capacity is the biggest burst the map has held.

**Why**: NativeTimerManager found due timers by iterating its whole `std.AutoHashMap` on every `poll`, every `getNextTimerDeadline` and every `getActiveTimerCount`. The Browser's loop calls those three each turn, and a worker's loop calls two. A std map's iterator visits every slot. Removals never shrink the map, and neither does a TombstoneGuard rehash, which rebuilds it at the same size. So after one page held 5,000 timers at once, every later turn on that loop read 8,192 slots three times. That lasted for the rest of the process, one loop per Browser and one per worker. The window's map of active timers (`timer_contexts`) and a worker global's (`WorkerHost.timers`) kept their peak capacity the same way. Every window's end, unload and back/forward suspension walked it. The worker's map also had no TombstoneGuard.

**What Happened**: Lane hashmaps1 guarded the timer maps' tombstones and then found the walk. Lane timerheap1 measured it before changing anything, using a test-build probe (`runtime.native_timer.Probe`) that counts the slots the search reads:
- tests/runtime/timer_heap_test.zig: 24 slots a turn before a burst of 5,000 and 24,576 after it, whether the burst was cleared or fired.
- tests/html/workers/worker_timer_heap_test.zig, a real WorkerThread loop: 16 slots a poll before the burst and 16,384 after.
- Context's map of active timers kept 8,192 slots after the burst was cleared.
- tests/html/workers/worker_timer_table_test.zig drives `@FieldType(WorkerHost, "timers")` the way setTimer and clearTimer do. In 299 of its 300 rounds the free slots had run out (capacity 64, none free, a mean miss of 64).

**Fix**: Do what the engines do:
- WebKit's ThreadTimers keeps a heap ordered by (fire time, insertionOrder). Each item stores its heapIndex, and `stop` removes the item by that index (Timer.cpp heapDelete).
- Chromium's delayed incoming queue is an IntrusiveHeap ordered by (latest_delayed_run_time, sequence_num). Blink's TimerBase::Stop removes its task by HeapHandle.

What changed in Crane:
1. The manager keeps a binary min-heap of entries ordered by (deadline, id), beside its id map. Each entry stores its `heap_index`.
   - `getNextTimerDeadline` reads the top of the heap.
   - `poll` pops due entries. It stops at the first entry that is not due, or that was armed after the poll began.
   - `clearTimeout` removes an entry by its index in O(log n).
   - The ordering is a linear extension of HTML's "run steps after a timeout" step 4.2, as the comment above `firesBefore` explains.
2. `runtime.native_timer.TimerIdMap(V)` serves the manager, `timer_contexts` and `WorkerHost.timers`. It uses std's names for its operations and combines a TombstoneGuard with a shrink. The shrink rebuilds the map smaller once fewer than a sixth of its slots are in use (WTF HashTable's `minLoad`).
   - Both the rehash and the shrink run only before an insert, never on removal, because owners remove entries while they walk the map. WTF shrinks on removal, but its iterators do not survive a mutation.
   - The heap's own array shrinks the same way.
3. After the change, a turn reads the same few slots before and after the burst, in both the window's loop and the worker's. The maps give their slots back at the next insert. lint-tombstones went from 70 to 69.

**Takeaway**: **When code asks "what comes next" on every turn, give it a structure ordered that way: a heap with stored indices, as WebKit and Chromium use. Walking the id map costs the table's high-water mark on every turn, and any long-lived map whose size swings needs a shrink as well as a TombstoneGuard.**
