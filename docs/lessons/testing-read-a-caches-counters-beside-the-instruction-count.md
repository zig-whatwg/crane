# Testing: Read a cache's counters beside the instruction count

**Date**: 2026-11-11
**Lesson**: When a change to a cache is gated on an instruction count, read the cache's own counters (hits, misses, entries) on the same bench and on the real pages too. The count can pass for a reason the bench was not built to test, and a page can lose hits that its count cannot show.

**Why**: Lane style1 b5 had two gates for a cache admission rule: the all-miss bench `gcsFull` may not cost more instructions than main, and the whole-page counts on the AG Grid and jquery pages may not rise. Both are instruction counts. Neither says what the cache did.

**What Happened**: Three things the counts alone would have hidden.
1. A bench passed for the wrong reason. `gcsFull` runs 10 rounds over the same 2,000 style attribute values. Before the cache keyed style attributes by content, no parent was ever looked up, so the bench was all-miss. With content keys, the entries one round leaves behind answer the next round's parents: with the first admission rule the bench came out at 0.9945 of main's, and the counters showed why - 2,685 hits, about 298 parents per round. A parent that is never seen again still pays more than on main (the content hash, the second key, a lookup that misses, a tag write); the bench's ratio is the sum of that cost and of those hits, and the bench cannot separate the two. With the final rule it is 0.9955 of main's with 2,771 hits in 20,000 parent lookups. The gate was met, partly by the bench's repetition, and the report has to say so.
2. A page lost hits its count could not show. The same rule cost the AG Grid page 7,987 of 1,188,349 hits. Each lost hit is one cascade, about 60,000 instructions: 0.05% of a page that retires 888 billion, under the noise of five runs. Only the miss counter (1,227 -> 9,214) showed it.
3. A control moved. One bench run was started while a census run of the same lane used the same host; the tip's control bench came out 1.5% higher than in the three runs before it (2,261.7 M instructions against 2,224-2,225 M), which shifts every per-resolution figure computed against it. The tip was measured last, while the other job loaded its largest page; that is the likely cause, not a proven one. Instruction counts are steadier than time, not immune to what else runs.

**Fix**:
1. Keep a build of each side that prints the cache's counters (here the census consoles) and run it on every bench and page the gate names.
2. For a bench, state what the count is made of: how many lookups hit, how many entries were made, how many prunes ran.
3. For a page, compare miss counts between the two sides. Equal misses is the proof that a rule lost no hit; the instruction count is not.
4. Run the instruction counts with nothing else of yours on the host, and check that each side's control is where it was in the last run before reading the ratios.

**Takeaway**: **An instruction count says what a change cost, not why. Read the hits, misses and entries next to it, on the bench and on the pages, before calling a gate met.**
