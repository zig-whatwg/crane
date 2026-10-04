# Architecture: An object many native lists hold is held by an edge from each list's owner

**Date**: 2026-10-04
**Lesson**: A PerformanceEntry sits in several native lists at once - its global's performance entry buffer, any number of observer buffers, a PerformanceObserverEntryList - and each list keeps it with a traced edge of its own (one `engine.traceChild` slot per entry, named by the entry's address), drawn when the entry goes in and forgotten when it comes out. No refcount, no root.

**Why**: An entry is a platform object the collector frees with its wrapper, and the lists are native `[]*Instance` the collector cannot see. A root per entry (`engine.retainValue`) would keep its realm alive through any detail that reaches back to the global; a refcount would need one owner to decide when the edge goes, and the owners are torn down in no order at the realm's end. A slot per (holder, entry) gives each holder its own edge: the Performance object's for the buffer, the observer's for its observer buffer, the entry list's for its entry list. Element's Attr nodes already use the same naming (`attr:{x}`), which bounds V8's private-symbol registry to the set of live addresses.

**What Happened**: The Performance Timeline batch needed `getEntries()`, `takeRecords()` and the observer callback's entry list to hand out the same entry objects that `mark()` returned, for as long as any list held them, and to let them go after `clearMarks()` or `disconnect()`.

**Fix**: `dom.performance_timeline.holdEntry(owner, entry)` / `releaseEntry(owner, entry)`. Two orderings matter: a list that hands entries to another holder draws the new holder's edge FIRST (the observer task makes the PerformanceObserverEntryList, which traces them, before the observer forgets its own), and `takeRecords()` builds its Array of wrappers before it empties the observer buffer - otherwise a collection in between frees an entry nothing holds. A Performance and the observers it lists hold each other only through slab-generation links, so either can be freed first.

**Takeaway**: **When several native lists hold one platform object, give each list's owner its own traced edge to it and move holders edge-first; never a root, never a shared count.**
