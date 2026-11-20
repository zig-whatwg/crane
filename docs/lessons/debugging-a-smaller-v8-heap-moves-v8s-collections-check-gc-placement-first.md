# Debugging: A smaller V8 heap moves V8's collections - check GC placement before chasing a cost row

**Date**: 2026-11-20
**Lesson**: When a change makes the V8 heap smaller and a cost row moves the wrong way, trace where V8's collections fall on both sides before looking for Crane code to blame: V8 sizes its young generation and its limits from what it has seen, so less memory at the start can mean more collections - or collections in a different place - later.

**Why**: V8's young generation starts small and grows only when objects survive (Heap::ResizeNewSpace), and its next full-collection limit is the size after the last collection plus a step plus the young generation's capacity (heap-controller.cc, `BoundAllocationLimit`: `max(limit, current + 8 MB) + new_space_capacity`). A build whose page setup allocates less meets the page's script with a smaller young generation and a lower limit. Two V8 behaviours then turn collection placement into cost:
- the fast JSON.stringify path restarts on the slow path at the first ConsString, even a flattened one (json-stringifier.cc, "TODO(pthier): Resume instead of restarting"), and only the scavenger shortcuts a flattened ConsString, while it is young (mark-compact.cc, "TODO(mlippautz): Handle ConsString");
- every full collection traces the live DOM through the node wrappers and settles the external-memory figure, so twice the collections on a DOM-heavy page is real CPU, booked to whichever workload is running.

**What Happened**: lane tmpl1 stopped deserializing interface objects that every realm then replaced (about 5 MB less V8 heap per realm; see `architecture-a-snapshot-object-you-replace-is-kept-twice.md`). The cost window showed json.stringify at 2x instructions and parser.dom-parser at +7% instructions. Neither was Crane code:
- json.stringify: the tip ran 3 scavenges inside the workload's 5,000-record loop (main ran 1), promoting records 0 to ~1,750 while their `'user' + i + '@example.com'` emails were still unflattened ConsStrings. Those records stringified 2.2x slower than flat copies of themselves, for the page's life. A 300,000-array preamble made MAIN the slow side (80 ms vs 32 ms).
- parser.dom-parser: the page's total was +0.9% (dom-parser +348 M instructions, document-write -209 M), and dom-parser alone was 2% cheaper on the tip. With the harness's event-loop turns, the tip started 13 full incremental collections over the three parser workloads to main's 6, each at the GLOBAL limit (V8 heap + the reported DOM): 11 of 12 MB with 2 MB of heap on the tip, 27-33 of 30-34 MB with 7 MB on main - the growing factor times main's bigger after-collection size let ~20 MB of DOM pile up between collections, the tip's 8 MB step ~9 MB.

**Fix** (the method):
1. Build a diagnosis console of each side with V8's tracing: `-Dv8-extra-flags=--trace-gc` (lane script: `V8FLAGS='--trace-gc --trace-incremental-marking'`, one argument). Never quote such a console's timings.
2. Align V8's timestamps with the page. V8's stdout is buffered, so the order of output lines means nothing. Record `performance.now()` marks in the page, end with `TestUtils.gc()`, and use that collection's trace line to get the offset between the two clocks.
3. Count instructions per phase without perf_bench: `/usr/bin/time -l <console> <url>` prints "instructions retired". Run the sequence prefix by prefix (A, A+B, A+B+C) and take the differences.
4. Test the hypothesis on its own: replace the suspect values (flat copies of the strings), or move the collections (a preamble that allocates). If the slow side flips, the row measures placement.
5. Bring the evidence for a ruling. Crane builds V8 unpatched, so a V8 cause is a bug report (filed by the user), not a patch: the JSON one is https://issues.chromium.org/issues/587998049 (2026-11-20).

**Takeaway**: **A cost row that moves after a memory win may be measuring where V8 now collects. Trace both sides' collections against page marks before changing Crane code, and prove it by flipping the slow side.**
