# Architecture: A released reservation's address goes to the next reservation - randomize placement and generation seeds

**Date**: 2026-11-10
**Lesson**: Release a large aligned reservation and reserve again, and both macOS and Linux hand back the same address - the oss review's probe P4: 7 of 7 times, on Linux even beside a second live reservation. A stale pointer into a released Browser then lands in the next Browser's heap, and if every Browser's generations start at 1, a (pointer, generation) pair from the old one can pass the new one's stamp check.

**Why**: Over-reserve-and-trim asks the kernel for "anywhere", and the kernel's first fit is the hole just released. Generation stamps are only a net if no two occupants of an address share a generation, which per-Browser counters starting at 1 do not give across Browsers.

**What Happened**: The node-memory plan claimed "after the Browser's end any stale pointer faults". Lane h1 built the per-Browser reservation (src/runtime/browser_heap.zig) on three counters to it: kit/posix reserves with random exact-size aligned hints first (PartitionAlloc's AllocPagesWithAlignOffset; none under ThreadSanitizer, where a hint can leave TSan's application ranges), so consecutive reservations land apart (tests/platform/h1_address_space_test.zig asserts at most 2 of 7 repeats); each Browser's generations start at a random value in [1, 2^55) from its own random stream (a seeded testing Browser replays it); and Debug builds - the bug-finding run - keep the last 4 released reservations inaccessible instead of unmapping them (Mozilla's aged graveyard, bug 1979830).

**Fix**: Never rely on "released means unmapped forever": randomize where reservations go, seed per-owner counters randomly, and in the bug-finding build hold freed address space back for a while.

**Takeaway**: **A stale pointer faults only until the address is reserved again - and the next reservation gets it at once unless placement and generations are randomized.**
