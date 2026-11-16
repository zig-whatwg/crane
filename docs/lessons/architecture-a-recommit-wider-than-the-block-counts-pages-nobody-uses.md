# Architecture: A recommit wider than the block counts pages nobody uses - recommit what a block can write, not the span it lies in

**Date**: 2026-11-16
**Lesson**: On macOS `MADV_FREE_REUSE` puts every page of its range that still holds its old bytes back into the footprint, written again or not, so an allocator recommits exactly the pages of the block it hands out.

**Why**: A page given up with `MADV_FREE_REUSABLE` leaves the footprint at once and keeps its bytes until the kernel needs a page. `MADV_FREE_REUSE` over a range turns each such page back into an ordinary dirty page of the process: counted, and no longer the kernel's to take. A recommit of a whole span for a block that uses part of it therefore brings back memory that nothing uses, and it is real memory, not a reading error. PartitionAlloc does not meet this because the span it recommits is sized to its slots (a few pages, or one large slot) and a direct map is committed for the size asked for in whole pages; an allocator whose span is far wider than its slots must commit piece by piece, as PartitionAlloc's own lazy commit does (`ProvisionMoreSlotsAndAllocOne`: from the page after the last slot handed out to the end of the page the new slot ends on).

**What Happened**: Lane ab1's in-sandbox allocator cut its range into 1 MiB chunks and recommitted every chunk it took from its free pool whole. The cost window read `fetch.loopback-gzip` at 137-142 MB where V8's default allocator held 116.5 MB of dirty pages. A full `vmmap` at the row's settled mark showed the tip's footprint equal to its dirty pages, and the dirty pages inside the allocator's range: each body is one block of 1 MiB and 7 bytes, a run of two chunks; 15 of the 39 lay on fresh chunks (1.02 MB dirty each) and 24 on chunks the row before had written 880 KiB of (1.00 + 0.86 MB dirty each) - 20.2 MB that no block used. Two process tests showed it alone: 32 buffers of 1 MiB + 7 bytes made where 2 MiB ones were freed raised the footprint by 64 MiB, and 48 small buffers (220 KiB in all, one size class each) on chunks given back raised it by 47 MiB.

**Fix**:
1. Recommit a large block up to its last page (the size asked for, rounded up to a page), and give back the same extent when it is freed.
2. Recommit a slot span that came from the free pool as its slots are first handed out: from the pages recommitted so far to the end of the page the new slot ends on. A freed slot handed out again is on pages recommitted already.
3. Keep the rule the other way round too: no byte is handed out on a page given back and not recommitted (lesson architecture-macos-recommit-needs-madv-free-reuse-or-the-footprint-undercounts.md).
4. Test both with a model that records PAGES and counts what the kernel would: a page that holds bytes and is accounted, whether or not it was written again. A model that records whole chunks cannot see either fault.

**Takeaway**: **A recommit is a charge for every page in its range that still holds bytes: make its range the block, never the span the block lies in.**
