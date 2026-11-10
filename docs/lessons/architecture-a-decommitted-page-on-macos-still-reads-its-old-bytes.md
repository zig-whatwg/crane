# Architecture: A decommitted page on macOS still reads its old bytes - write the dead marker before decommitting

**Date**: 2026-11-10
**Lesson**: `madvise(MADV_FREE_REUSABLE)` on macOS returns a page's memory without zeroing it: until the kernel reclaims the page, a read still sees the old contents (Linux `MADV_DONTNEED` reads zero). An allocator whose freed blocks keep a sanctioned "is it still mine?" word (a generation stamp) must write that word dead BEFORE it decommits, or a stale holder can read a live-looking stamp from a decommitted page.

**Why**: The node-memory design (tmp/redesign/node-memory-architecture.md 5.2) keeps each node block's generation stamp at its offset 0 and lets raw `*Instance` holders read it after the block is freed, as the slab's stamps are read today. Its safety argument needs every page state - live, freed, decommitted, reissued - to read either the current generation or dead. On Linux a decommitted page reads 0 (dead); on macOS it may read whatever was there.

**What Happened**: Lane ndalloc b1's vmasplit microbenchmark (tmp/plans/ndalloc-bench/bench.zig) wrote 1 to the first byte of 10,000 and 40,000 committed 16 KiB spans, decommitted them, and read the first byte back: `after-decommit byte=1` on chat.local (macOS 27.2, MADV_FREE_REUSABLE), `byte=0` on server1 (Linux 7.0, MADV_DONTNEED). The same run measured why spans are decommitted with madvise rather than mprotect: mprotect left two map entries per span (20,001 / 80,001 on macOS, 20,024 / 80,024 VMAs on Linux, against a stock `vm.max_map_count` of 65,530); madvise left 3-24.

**Fix**: The free order in the design: set the stamp dead, then poison the rest of the block, then quarantine it, and decommit an empty span last - so every state reads dead. H3's red test reads a stamp after decommit on both OSes.

**Takeaway**: **Decommit is not zero on macOS: whatever a freed block must say after its free (dead, poisoned), write it before the decommit, and test the read on both OSes.**
