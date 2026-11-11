# Debugging: A per-query cache can cost more than the lookups it saves - measure it

**Date**: 2026-11-10
**Lesson**: "Find the Browser and its tables once per query instead of once per element" read as a sure win, and measured as a large loss. Treat a cache in a hot matcher as a hypothesis: measure instructions per op before and after, and revert it when they rise.

**Why**: Lane nd2 batch 2 decodes attribute ids through the Browser's tables. The selector matcher reads an element's classes once per visit, so each visit paid an address lookup (`BrowserScope.ofInstance`) and an acquire load of the values table. The fix seemed obvious: keep the Browser and the table on the Matcher and pass them down.

**What Happened**: First the cache rode in the per-element view, which grew from 24 B to 40 B. querySelectorAll went from 1.052 to 1.228 against main and matches from 1.029 to 1.111. Back at 24 B, with the cache kept on the Matcher only, the numbers were 1.166 and 1.068. Instructions per op rose by about 50 per element visit, and no reading of the code explained it. Reverting the matcher to the plain per-visit lookup gave 1.043 and 1.035 (instructions +3.5% and +1.6%). A `sample` profile then showed the remaining cost spread over the class-check path, with no single owner.

**Fix**:
1. Measure instructions per op (perf_bench journals carry them), not only time: they are quieter than wall time.
2. Change one thing per measured build.
3. If a cache does not lower instructions, revert it, even when the reasoning says it should.

**Takeaway**: **In a hot path the compiler's inlining and the call shapes decide what a "saved lookup" costs. A cache is a hypothesis until instructions per op go down.**
