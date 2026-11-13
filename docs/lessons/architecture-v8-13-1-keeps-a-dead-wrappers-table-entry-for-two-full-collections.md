# Architecture: V8 13.1 keeps a dead wrapper's CppHeapPointerTable entry for two full collections

**Date**: 2026-11-10
**Lesson**: In V8 13.1.203, every new CppHeapPointerTable entry is born marked. A full collection's sweep frees only unmarked entries and unmarks the rest. So the entry of a wrapper that dies right after it is made survives the first full collection and is freed only at the second, and the table holds two GC intervals of dead entries, not one.

**Why**: The details are in 13.1.203:
- src/sandbox/cppheap-pointer-table.h, `Payload::Tag`, ORs `kCppHeapPointerMarkBit` into every entry that `MakePointerEntry` writes.
- src/sandbox/cppheap-pointer-table.cc, `SweepAndCompact`, adds an entry to the freelist only `if (!payload.HasMarkBitSet())`, and otherwise clears the bit.

This is black allocation applied all the time, not only while marking. V8 removed it in 60611ef018b (2024-10-18; the first tag that contains it is 13.2.29), "[sandbox] Don't black-allocate CppHeapPointerTable entries", bugs 372524119 and 40928281. Since then an entry is marked at birth only when `space->allocate_black()`, which is during marking (V8 14.6 `MakePointerEntry(value, tag, mark_as_alive)`). Chrome 131 ran V8 13.1; Chrome 132 and later do not pay this.

**What Happened**: Lane wr1 batch 10 measured the user's restated churn condition: gc_bench, 12M dropped wrapped divs, `--loop`, chat.local. The tip's max RSS was 149-154 MiB and the base's (P2, internal fields) 77 MiB, a gap of 75.5 MB. The condition allows 8 B x the drops per full-GC interval (~4M) x 1.10 = 35 MB, so it failed by about 2x.
- The resident series showed what the table does. Resident climbed 8.0-8.8 B per drop. The full collection at ~2M drops freed nothing. The one at ~7.1M freed 13 MB, the drops from before the first. The one at ~11.4M freed 38 MB, the ~5M drops between the first and the second.
- So each collection freed the interval before last, and the peak was 8 B x ~9.4M = 75 MB: two intervals.
- malloc (16 MB) and the Zig side (11.5 MB) stayed flat, the C++ heap was ~0.6 MB, and no anchor waited. That left the table as the only thing growing.
- A bracket of runs to N drops (N from 1M to 12M, 2 rounds, counting full collections) measured where they fall: the first at 1.0-1.5M, the second at 5.0-6.5M, the third at 10-12M. So one interval was 3.5-5.5M drops (an allowance of 31-48 MB) and two were 8.5-11M (75-97 MB).
- On the release console's churn page (64 rounds of 260,000 drops), the footprint climbed 2.0-2.1 MB a round, from 104 MB to 240 MB. It fell once, at round 57 (~14.6M drops), to 137 MB; the base was then at 134 MB. A probe 4x as long as the first one (8.3M drops) had shown no fall at all.

**Fix**: A bound on table entries counts the drops of TWO consecutive full-GC intervals while Crane links V8 < 13.2, and one interval plus the marking window after an update. When measuring, find where the collections fall: run to several N and read the full-GC count, rather than inferring positions from a sawtooth. The table cost of a dropped wrapper halves with the V8 update; no Crane change can reach it.

**Takeaway**: **Before bounding an engine structure by "freed at the next collection", read how its sweep decides what is dead in the version you link: a structure that is born marked survives one more collection than its object.**

**Status (2026-11-13, lane wr1 batch 11)**: V8 15.7.112.43 has the upstream fix - an entry is born unmarked outside a marking cycle (src/sandbox/cppheap-pointer-table-inl.h:17-31, :143-147) and goes at the first full collection after its wrapper dies. The churn footprint did NOT improve with it: the cost was never how many collections an entry lived through but that nothing asked for a collection at all (2 full collections in 12,000,000 dropped wrappers). Closed by telling V8 about the entries (lesson architecture-freeing-ahead-of-the-collector-removes-the-growth-it-paced-itself-by.md).
