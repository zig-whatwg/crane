# Testing: V8 counts traced handles in its used global handle bytes

**Date**: 2026-11-11
**Lesson**: `HeapStatistics::used_global_handles_size()` is global handles PLUS traced handles (`Heap::UsedGlobalHandlesSize`, heap.cc 1006-1009 at V8 15.7.112.43). A `TracedReference` a cppgc object holds shows up there until the object dies or the reference is reset.

**Why**: Crane's "a realm's end leaves no handle of its own" tests read that number before and after a realm (`global_handle_bytes`). They were written when every handle was a `Global`. A traced reference lives as long as the C++ object that holds it, and that object is collected only when nothing reaches it, which may be some time after the realm's end.

**What Happened**: In lane v8up b3c, every realm global's GlobalAnchor traced a retained-store object. worklet_realm_test and worker_iterator_template_test then saw +16 B per realm after its end: the anchor's TracedReference node, waiting for the collection that would take the old global.

**Fix**: The realm's end (`GlobalAnchor::clear`) resets the reference along with the instance pointer. What the store held belongs to the ended realm, whose wrapper cache is torn down. Resetting a TracedReference is safe beside a concurrent marker, as Blink resets `TraceWrapperV8Reference`.

**Takeaway**: **A handle-byte check covers traced references too: anything a cppgc object traces must be released at the end that the check measures, or the check will see it.**
