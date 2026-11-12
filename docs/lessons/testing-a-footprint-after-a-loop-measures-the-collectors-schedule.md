# Testing: A footprint read right after a loop measures the collector's schedule - read it at marks, with a forced collection, before calling it live memory

**Date**: 2026-11-11
**Lesson**: When two engine versions differ in footprint at the end of a workload, read the footprint at fixed marks in one process - loaded, right after the loop, after idle time, after forced collections, later - before attributing the difference: what is gone after the forced collections was garbage the collector had not reached yet, what stays is live memory or a peak the allocator never handed back, and what differs on an idle page is a fixed cost with its own cause.

**Why**: A footprint at the end of a workload is the sum of four different things - a fixed per-process cost, live objects, garbage not yet collected, and native memory whose peak is not returned - and a ratio hides which one moved. Each has a different owner and a different fix; only the marks tell them apart.

**What Happened**: The V8 13.1 -> 15.7 port's perf pair read MEMORY 1.33 against main (time 0.90), with rows as far apart as dom.event-ctor 217 MB vs 148 MB, while the per-wrapper cost measured elsewhere was +21 to +43 bytes. One console per side on a blank page, vmmap at five marks (.v8up/gcdiag-b4.sh), took it apart in minutes:

- loaded: 27.9 vs 23.9 MB - a fixed +4 MB, found separately in the exit memory graph: one 278,528-byte thread-local block per thread that touches any thread-local, 14 blocks against 1;
- 3,000,000 dropped JS objects: 31.6 vs 27.6 after the loop; after 4 s of idle main had fallen to 22.1 by itself and the tip had not moved (31.7, and 31.8 after 17 s); after two forced collections 25.5 vs 22.1 - the fixed cost and nothing else;
- 100,000 kept divs: 62.3 vs 58.8 after forced collections - again only the fixed cost;
- 300,000 dropped Events: 166.1 vs 137.3 after the loop, 128.7 vs 130.9 after forced collections; the same Events in chunks with the event loop turning: 98.4 vs 74.8, and 83.4 vs 69.5 after forced collections - a peak that stays.

So the 1.33 was not bigger objects: it was a fixed cost, a collector that no longer runs in idle time, and a higher peak during garbage loops. Two hypotheses about the last one were disproved with the same marks before any build was made.

**Fix**:
1. Read the idle page first: a difference there is per process, not per object. Take the exit memory graph under MallocStackLogging (`leaks --atExit --outputGraph`, `heap -s`, `malloc_history -callTree`) to name it.
2. Run the workload's loop alone in a console and read the footprint at: loaded, after the loop, after idle time longer than the engine's own delays, after two forced collections, and a few seconds later. Do it for a garbage loop, a pure-JS garbage loop, and a loop that keeps its objects.
3. Classify: gone after the forced collections = not yet collected (the collector's schedule); still there with kept objects = live; still there with dropped objects = a peak not returned.
4. Only then build anything. A hypothesis about scheduling can usually be tested by changing the page (chunk the loop, lengthen the idle time) before it needs a flag.

**Takeaway**: **A footprint after a loop is four numbers added together: read it at marks, once with a forced collection, and name each part before explaining the sum.**
