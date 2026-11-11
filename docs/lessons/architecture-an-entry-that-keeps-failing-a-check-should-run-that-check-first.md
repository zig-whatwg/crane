# Architecture: An entry that keeps failing a check should run that check first

**Date**: 2026-11-11
**Lesson**: When a cache lookup runs a long conjunction of checks against entries that fail it the same way every time, keep on each entry the value that rejected it last and compare that value first. The compare is one the full check makes, so it orders the checks and decides none: no hit is hidden, and a rejected entry costs a few instructions instead of the whole conjunction.

**Why**: A conjunction is cheap only when its first checks are the ones that fail. In a matched-properties cache the checks run in a fixed order (pseudo-element, context scalars, the matched list, the parent's flags, its inherited values, then, under explicit inheritance, its non-inherited values), and the order suits hits: everything has to pass anyway. A key whose entries were made under parents that differ only in a value the cascade inherited explicitly fails each entry at the last check, after paying for all the others. A fingerprint of "what the check compares beyond the key" would have to hash values exactly as the check compares them (bit identity, or Value.eql for allocated payloads), and every lookup, hits included, would pay to compute it.

**What Happened**: Lane style1 batch 4. The all-miss bench gcsFull (each row under a parent with its own `margin-left`, the row `margin-left: inherit`, one key for all) ran four full correspondences per row: +2.77% of a resolution against main. A red test counted 86 full correspondences over 24 misses of a four-entry key. Each entry now keeps `rejected_at` (the group and index of the parent value its last correspondence failed on: `firstUnidentical` names it, so does the justify-items check) and the lookup first asks `identicalAt` there. The same test counts 4: each entry runs its full correspondence once, for the first parent it does not stand for. A parent with an entry's value there still hits after one correspondence (the test checks it). gcsFull's find, record and key part fell from 3,199 to ~100 instructions per resolution, and the hit benches did not move (0.553 to 0.555 of base).

The adoption scan had the same shape: a group that no entry holds equal was compared with each of the four entries from its first value. The fix was the same: keep per group the index where it last differed and compare that first, and compare only the groups still held alone. That took 47 values compared down to 19.

**Fix**:
1. Count the full checks run per lookup in a test before changing the order (a counter on the cache; the red test asserts the bound).
2. Record where a value check failed (group and index), not just that it failed; keep it on the entry, or per group for a scan.
3. Check the recorded place first with exactly the compare the full check uses at that place. Any place is then a valid hint: a stale one costs one extra compare.
4. Test that a lookup equal at the recorded place still reaches the full check and hits.

**Takeaway**: **A check that keeps rejecting the same entries is a hint you already have: remember where each entry failed and compare there first. It reorders the conjunction without deciding anything, so it costs hits nothing and hides none.**
