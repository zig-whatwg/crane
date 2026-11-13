# Testing: Browsers' memory under DOM churn is a GC sawtooth, not flat

**Date**: 2026-11-10
**Lesson**: Chrome, Firefox and Safari do not hold a flat footprint across rounds of create-and-drop DOM churn; each rises between collections and drops at them, so "flat" is not the browsers' bar - bounded by GC is.

**Why**: Blink's nodes are cppgc objects (Node : EventTarget : ScriptWrappable, Chromium 145.0.7608.0), so churn grows the C++ heap, and CppHeap::ReportBufferedAllocationSizeIfPossible schedules the full collections that also sweep its wrappers' table entries. Between two of them the footprint climbs.

**What Happened**: Lane wr1 batch 9 ran batch 8's churn page (8 rounds of dropped wrapped divs) through perf_bench on chat.local (2026-11-10 04:35-04:36, every process of each browser, 2 runs): Chrome 157.0.8103.38 471-535 MB, a drop to 319 MB at round 4, then +26 MB over rounds 4-8; Firefox 159.0.1 364/400 -> 665/689 MB (5 -> 9 processes); Safari 27.2 about 250-330 MB with drops at rounds 4 and 7. Crane's tip on the same page: 102 -> 128 MB, the base 96 -> 101. The condition "churn flat" had been set against a Crane baseline, and no browser meets it.

**Fix**: Measure the browsers on the same page first, then state the bar in their terms (here: bounded by GC, the plateau explained by what the engine frees only at a full collection).

**Takeaway**: **Measure the browsers on the same page before setting a memory bar against a Crane baseline: a condition the browsers fail is a choice to make explicitly, not a conformance target.**
