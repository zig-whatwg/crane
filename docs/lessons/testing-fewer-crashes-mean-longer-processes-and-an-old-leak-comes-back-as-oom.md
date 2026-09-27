# Testing: Fewer crashes mean longer processes, and an old leak comes back as an OOM

**Date**: 2026-09-27
**Lesson**: A sweep that crashes less restarts its shard processes less, so a slow leak the restarts were hiding reaches V8's heap limit and comes back as `FatalProcessOutOfMemory` - with no new leak anywhere.

**Why**: The supervisor respawns a shard child after every crash and every stall-watchdog kill, and a fresh child starts with an empty heap. Crashes were the sweep's memory reset. Whole-page retention - about one native context and 1-2 MB per file - is harmless over 300 files and fatal over 1,000.

**What Happened**: The sweep at 2b6963525 improved crashes from 28 to 5, and two of the five were OOM in html5lib files (shards 1 and 2, ~960 files into one process, 1.15-1.2 GB of heap). The first suspicion was frame realm retention brought back by a realm migration. The journals said otherwise: over the whole sweep, per-file retention was LOWER than at ee5bedd70 (0.82 native contexts and 1.75 MB per file, against 1.26 and 2.77), html5lib's retention was identical, and a 30-file forms slice under `CRANE_HEAP_GC=1` gave the same numbers on 2b6963525 and on the build before the migration. At ee5bedd70 shard 1 had simply restarted at file 2728, so it reached html5lib with 130 MB, not 1.1 GB.

**Fix**: Attribute an OOM by per-file retention, never by crash counts: the floor of `native_contexts` (the minimum over the rest of the process) rises only where a file leaves something behind, and summing that per area, between two sweeps, says whether retention changed. Then reduce the retention - here the biggest single pinner, `captureDOMExceptionStack`'s three Globals per DOMException (tests/v8/page_realm_operations_test.zig pins it) - and log the rest (tmp/plans/lifetime-queue.md). A long reproduction must run under the supervisor (`--from-file=<list> --parallel=1`), as the sweep did: without the stall watchdog the first hanging file stops the run, and without restarts the heap curve is not the sweep's.

**Takeaway**: **A drop in crashes can raise the peak heap. Compare retention per file, not crashes, before calling an OOM a regression.**
