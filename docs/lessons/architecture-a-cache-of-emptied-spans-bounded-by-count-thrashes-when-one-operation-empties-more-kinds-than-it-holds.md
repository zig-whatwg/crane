# Architecture: A cache of emptied spans bounded by a COUNT thrashes when one operation empties more kinds than it holds - bound it by bytes

**Date**: 2026-11-16
**Lesson**: An allocator that lets an emptied chunk wait before it goes back to the OS must not bound what waits by a small count. One engine operation can empty chunks of more size classes than the count, and then every operation gives chunks back and fetches them again. Bound what waits by its dirty bytes, counted in whole pages, oldest first.

**Why**: Crane's in-sandbox allocator (src/runtime/engines/v8/sandbox_allocator.zig, lane ab1) keeps one size class to a 1 MiB chunk and lets an emptied chunk wait, as PartitionAlloc lets an empty slot span wait in a ring (partition_page.cc RegisterEmpty), so that a free followed by an allocation makes no system call. PartitionAlloc's ring has 16 places by default; a foreground renderer and V8's own d8 allocator raise it to 128. Lane ab1 took 16. A BigInt's decimal string takes scratch blocks of many sizes, each freed before the next is taken: more than 16 chunks empty in turn, each new one pushes the oldest out, and the next operation needs the one just pushed out.

**What Happened**: An untimed look on chat.local (gc_bench, 4,000 operations, against main's console) read the BigInt row at 10.4 G instructions against 14.6 G - and system time 0.08 s against 0.01 s. The first explanation (a chunk changed its place in the ring whenever it was used again) was coded, pinned by a model test and reported as the fix; the same look on that commit read 0.07 s. The cause was then found by an experiment with a prediction: buffers of 12 sizes made and freed in turn read 0.01 s of system time against main's 0.02 s; of 40 sizes, 0.16 s against 0.06 s, with 4.6 to 4.9 G instructions against 3.6 G; the BigInt product alone 0.01 s; its decimal string alone 0.06 s with twice main's page reclaims. With the count gone the 40-size row read 0.01 s against 0.07 s and 1.77 G against 3.60 G, and the BigInt row 9.4 G against 14.6 G with main's system time.

**Fix**:
1. No count: the emptied chunks wait in a list, the one that emptied first at its head (`wait_head`); a chunk that empties again is the newest.
2. One bound, the dirty bytes that wait (`retained_max`, 1 MiB), the oldest going back while it is passed.
3. Count a chunk's dirty bytes in whole pages (`dirtyBytes`): a chunk with one 64-byte slot used holds a page (16 KiB on Apple silicon), not 64 bytes - or forty such chunks read as 2.5 KiB while they hold 640 KiB.
4. Tests on a model address space pin both: forty chunks wait with no page operation; 896 KiB more send the eight oldest back.

**Takeaway**: **Bound a wait-before-release cache by the bytes it holds, in pages, never by a small count of entries: the count is a guess about how many kinds one operation touches, and an engine's own operations (BigInt conversions, regexp vectors) break it.**
