# Testing: gc_bench's end-of-run counts without --gc are the last batch, not retention

**Date**: 2026-10-09
**Lesson**: gc_bench runs its body in batches of 5,000 cycles, one script per batch, and collects between batches only with `--gc`. Without `--gc`, the wrapper entries and handle bytes it prints at the end include everything the last batch made that is still uncollected. A count that equals (cycles per batch) x (objects per cycle) is that batch, not a leak.

**Why**: gc_bench forces collection only when asked (tools/gc_bench.zig, `force_gc`). Garbage from the last script is still there when the counters are read, unless a collection happened on its own.

**What Happened**: Lane edges reported "MO deliver: base already retains one wrapper entry per two cycles (10,008 entries, identical in all 7 rounds = deterministic retention)" and queued an investigation. Lane nodeholds re-ran the body at 2f625a901f: without `--gc`, base ended at 10,008 entries, which is the last batch's 10,000 delivered MutationRecords (5,000 cycles x 2 records, wrapped by delivery and not yet collected) plus the page's 8. With `--gc`, base and tip both ended at 8 entries in all 7 rounds.

**Fix**: Measure retention with `--gc` (two collections and a microtask checkpoint per batch). Before calling an end count "retained", divide it by the batch size (5,000) and see whether it is a whole number of objects per cycle.

**Takeaway**: **"Identical in every round" proves the count is deterministic, not that anything leaked. A whole number of objects per cycle in the last batch is the harness. Measure retention with --gc.**
