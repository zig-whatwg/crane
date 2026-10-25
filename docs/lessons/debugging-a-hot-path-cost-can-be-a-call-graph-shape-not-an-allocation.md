# Debugging: A hot-path cost can be the call graph's shape, not an allocation

**Date**: 2026-10-25
**Lesson**: Before accepting a hot-path slowdown as "structural", check the call graph's shape (recursion, lost inlining) as well as allocations and sample counts.

**Why**: A cost that allocates nothing and spreads evenly over the existing functions looks like "more work per item". A new mutual recursion between two hot functions produces exactly that picture: the compiler can no longer inline them, so every item on the path pays, not only the new ones.

**What Happened**: Codex row 119's e1+e2 added 14 inherited font longhands and image_computed rose 0.750 ms (+8.08% paired). The profile put the extra time in compute / computeValue across the board. The bounded check (Q212 C) traced every new longhand's inherit and initial paths, and counted allocations (equal calls on both sides, +448 B per ComputedStyle). Finding nothing narrow, the integrator accepted the cost as the per-longhand cascade cost already seen at Q121, though at about 5x Q121's rate per longhand. Lane cascadefast1 then found that about 0.6 ms of it was ONE line in e2: computeValue's font_size_adjust `.unavailable => self.compute(l, self.unset(l))` made compute and computeValue mutually recursive. Removing it alone took the cascade benchmark from 2.95 to 2.35 ms per 1,000 elements. The 14 slots themselves cost about 0.24 ms, which is Q121's rate.

**Fix**:
1. When a cost is spread across existing functions, look for new recursion or new indirect calls on the hot path (grep the change for calls back into the caller's callers), and for a per-item rate far above earlier measurements of the same mechanism.
2. A defensive fallback on a hot path produces its value directly (here: retain the parent's value, since font-size-adjust is inherited) instead of re-entering the dispatcher.
3. Treat "about 5x the known per-item rate" as a finding to explain, not a rounding difference.

**Takeaway**: **An allocation count and a flat profile cannot see a recursion that blocks inlining; check the call graph's shape before calling a hot-path cost structural.**
