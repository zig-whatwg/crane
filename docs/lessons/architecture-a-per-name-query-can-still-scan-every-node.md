# Architecture: A per-name query can still scan every node

**Date**: 2026-10-17
**Lesson**: Removing allocations from a named-property query does not make a document walk cheap enough to run before every ordinary property read.

**Why**: Document is `[LegacyOverrideBuiltIns]`. Its named-property query runs before reads such as `document.body` and `document.createElement`, even on pages with no named elements. An allocation-free query that scans all descendants still makes every miss linear in document size.

**What Happened**: Row 63's prototype implemented the document named-element filter and existing live-collection seam, and exposed an allocation-free `isSupportedPropertyName` delegate. It improved the targeted named-access results and passed the retained-collection GC case. On the approved 10,000-element / 100,000-read cost page, four completed alternating priority pairs gave median `document.body` times of 1,879.8 ms on BASE and 46,770.15 ms on the prototype (24.88 times as long). Each prototype page hit its 60-second ceiling before the remaining property-read cases finished. The liaison stopped further pairs and the prototype was withdrawn before commit.

**Fix**: Keep the fixture and rejected patch as evidence. Route a maintained id/name index together with stable collection identity to the owner of node mutation and object lifetime. A version-keyed cache still rebuilds after each mutation and does not solve a mutate-then-read loop. Keep ordinary property reads in the cost bar even when the feature's conformance tests pass.

**Takeaway**: **A per-name delegate is the right binding seam, but its negative answer must not walk the document on every read.**
