# Architecture: A bug-finding heap must not retire the span it allocates from next

**Date**: 2026-11-23
**Lesson**: When a detection build makes a fully freed span inaccessible (discard, then PROT_NONE), it must skip the span its bucket allocates from next - the lowest one with room - or a block made and freed alone pays four syscalls and a span-sized memset on every cycle.

**Why**: A span empties whenever its last live block is freed. In a churn of one block at a time (`new Event()` in a loop, one node made and dropped per task) that is EVERY free, and the very next allocation needs the span back: recommit (mprotect + MADV_FREE_REUSE on darwin), and in a poisoning heap a memset of the whole span to start it over - 16 KiB to issue one 112-byte block.

**What Happened**: Lane hard1 (allocator hardening batch A, src/runtime/heap/) gave the bug-finding run's heap the design's "PROT_NONE on fully freed spans" (tmp/plans/allocator-hardening-design.md 3.6). Retiring on every emptying turned a single-object churn into a retire/recommit pair per object - the bug-finding WPT sweep's wall time is a gate of its own.

**Fix**: In `Engine.release`, retire an emptied span only when its bucket's current span (the lowest with room) is a LOWER one: then this span is not the next allocation's, and making it inaccessible catches a stale read without paying for it on the next allocation. The lowest span stays committed (empty-cached) and is decommitted - never protected - by the idle loop like any other.

**Takeaway**: **A detection that changes a page's protection belongs on memory the allocator will not hand out next; measure a one-block churn, not only a bulk free, before turning it on.**
