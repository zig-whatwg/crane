# Debugging: An API that looks like a field write can allocate on the collector's heap

**Date**: 2026-11-11
**Lesson**: On V8 15.7 every `SetAlignedPointerInInternalField` allocates a cppgc object that only a full collection frees.

**Why**: An engine update can keep an API's signature and change what it costs. With pointer compression V8 15.7
stores an aligned internal-field pointer as a cppgc `EmbedderDataSlotWrapper` (16 B + an 8 B header) reached through
the CppHeapPointerTable (8 B): `EmbedderDataSlot::store_aligned_pointer`, src/objects/embedder-data-slot-inl.h:212-227.
V8 13.1 wrote a young external-pointer-table entry that the scavenger swept (:124-143). cppgc has no young
generation, so the 32 B outlive the wrapper until a full collection, and a loop of short-lived wrappers causes none.

**What Happened**: After 300,000 dropped Events the port's footprint read 166 MB against main's 137 MB, and after
forced collections it read LESS than main (128.0 vs 134.2). Two hypotheses about scheduling were disproved, and a
third (the young generation's size) fell to a trace: both versions scavenged every 2.0 MB, with no mark-compact,
and `--max-semi-space-size=8` changed nothing. What separated the causes was a second count: with 1,200,000 Events
the V8-tagged regions grew from 22.8 to 50.6 MB on the port and stayed 13.4 MB on main - 30.9 B per dead wrapper,
linear in the count, returned by one forced collection. A cost that grows with the number of dead objects and that
a full collection takes back is garbage on a heap the young collector does not visit; the source search for who
allocates there took minutes once the question was that narrow.

**Fix**:
1. Run the workload at two sizes and read each memory region at both: constant, proportional to the peak, or
   proportional to the count are three different causes.
2. Read what a forced collection returns. If it returns the excess, ask which heap holds it and which collector
   visits that heap.
3. For each engine call on the wrapper-creation path, read its implementation at the new version, not its header.
4. The fix belongs to the wrapper model (`Object::Wrap` with one traced object per wrapper, as Blink); note there
   that a cppgc object per wrapper has the same reclaim class.

**Takeaway**: **When memory grows with the number of dead objects and a full collection returns it, something on
the creation path allocates on a heap the young collector does not visit - measure at two sizes, then read the
implementation of every engine call on that path at the version you link.**
