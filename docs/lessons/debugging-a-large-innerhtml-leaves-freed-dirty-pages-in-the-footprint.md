# Debugging: A large innerHTML leaves freed-but-dirty malloc pages in the footprint

**Date**: 2026-11-10
**Lesson**: A footprint per parsed element read after one big innerHTML includes the parse's transient high-water. malloc keeps freed pages dirty, and the physical footprint counts them, so the figure overstates what the nodes hold.

**Why**: The HTML parser and the fragment's insertion allocate transient structures in proportion to the nodes they make, then free them. macOS libc malloc keeps freed small-zone (and some large) pages resident and dirty until memory pressure. vmmap's "Malloc Small (empty)" and "Malloc Large (empty)" rows are those pages.

**What Happened**: In lane nodedata batch 1, tests/perf/elements.json's parser span read 643 B per span, against 480 for the same 100,000 spans made one insertAdjacentHTML at a time in the same console (and 406 for a parsed div in gc_bench after forced GCs). malloc's LIVE bytes differed by only 19.8 B per span (437.8 against 418.0). vmmap after the big parse showed 170.9 B of "Malloc Small (empty)" and 24.2 B of "Malloc Large (empty)" per span still dirty, against 79.5 + 0 for the per-cycle case. The one extra live allocation was a single ~2.2 MB block (22 B per child) held after the innerHTML setter, under mutation.replaceAll -> insert -> removeHeld.

**Fix**:
1. Before reading a parser-path footprint as node storage, split it with vmmap: live malloc (zone "allocated") against the "(empty)" rows.
2. Compare it with the same nodes made in small batches.
3. Report the high-water separately: real pages are parsed this way, so it is a real cost, but it is not the node's.

**Takeaway**: **A footprint taken after a big parse holds the parser's freed pages too: split live bytes from "(empty)" dirty pages before charging them to the nodes.**
