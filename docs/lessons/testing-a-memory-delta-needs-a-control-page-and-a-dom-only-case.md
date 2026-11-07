# Testing: A memory delta needs a control page, and a cross-engine one a DOM-only case

**Date**: 2026-11-07
**Lesson**: Bytes per element from two footprint readings is only as good as what else the process did between them. A page that runs the same steps and makes nothing (the control) measures that drift, and it can be larger than the objects; and in a browser that renders, a node in the document costs its layout object and computed style too.

**Why**: A fresh engine is still settling when the page loads. Firefox has no collection a page can ask for, frees startup memory on its own timers, and its whole process set fell by about 32 MB over the 6-7 s between the readings with nothing made - 320 B a node at N = 100,000, more than its whole cost of a div. Separately, Chrome, Firefox and Safari give every node in the document a layout object and a computed style: Chrome's div cost 173 B kept in a JS array and 850 B in the document, its parsed span 1,654 B. Crane and Lightpanda draw nothing, so their two figures match.

**What Happened**: perf3 batch 2 measured memory per kept node in every engine (tests/perf/elements.json, perf_bench `retained` pages, one case per fresh launch). The control page's deltas were: Crane +0.8 MB, Chrome -1.9 MB, Safari -0.3 MB, Lightpanda +0.3 MB, Firefox -30 to -40 MB. Without the control Firefox's detached div would have read -79 B a node in one run; with it, 209 B (MAD 12). Crane's own figure validated against gc_bench of the same build within 3% (2,259 vs 2,325-2,334 B).

**Fix**: Report every case as (case difference - the control's median difference) / N, per run, with the runs' median absolute deviation; name an engine whose control drift is large, and say which cases include rendering (report.zig's method footnote does both from the rows). Compare engines on the DOM-only case - nodes kept in a JS array, outside the document - and give a display:none host to any in-document case meant to be DOM-only.

**Takeaway**: **Read the control page's own drift before any per-object figure, and compare engines on nodes outside the document: a renderer's in-document node carries its layout object and style.**
