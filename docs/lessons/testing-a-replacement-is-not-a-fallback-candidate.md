# Testing: A replacement is not a fallback candidate

**Date**: 2026-10-24
**Lesson**: Keep fallback declarations in separate cascade candidates and include a fallback different from the initial value.

**Why**: CSSOM setProperty replaces the earlier value of that property in the same declaration block. An expected result equal to the property's initial value can then pass by defaulting, without exercising fallback selection.

**What Happened**: A filter test set none and then blur(1cap) in one block. Missing cap metrics made the result none, but the earlier declaration no longer existed. The test proved defaulting, not choosing a retained candidate.

**Fix**: Put the earlier and later declarations in two author blocks with explicit source order. Test both none and a distinct blur(2px) fallback, then serialize after the declaration blocks are destroyed. Run every allocation-failure case as well.

**Takeaway**: **Preserve the fallback candidate, and choose a sentinel that distinguishes it from the initial value.**
