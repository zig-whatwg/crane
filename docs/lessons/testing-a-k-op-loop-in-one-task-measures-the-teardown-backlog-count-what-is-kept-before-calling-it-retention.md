# Testing: A K-operation loop in one task measures the teardown backlog - count what is kept before calling it retention

**Date**: 2026-11-22
**Lesson**: A footprint that grows with K, read after a collection at the end of a page whose K operations all run in ONE task, is mostly the peak that task reached: Crane frees dead trees between tasks (runtime.gc.DeferredTeardown, inline only past `high_water` = 100,000 queued nodes), its state arena keeps every block it ever handed out on its free lists, and malloc keeps freed pages. Count what is still alive - by interface, after collections and an idle loop - before naming a structure that "grows per operation".

**Why**: tpc's delete-join K-sweep (perf_bench, a timed page of K joins, `footprint_collected - footprint_start`) read +2.3 MB at K=250 and +19.6 MB at K=8,000 without A04, and an 8 s settle changed nothing - which looked like document-lifetime growth. The settle only proves the backlog is gone by the reading, not that its residue is.

**What Happened**: gc_bench's new columns (lane mem1: `--batch=K` runs K operations per script, `--settle` drains the queue before each reading, `--live-types` lists the live objects by interface) on server1: the teardown queue held 1,000-5,700 nodes at the end of a 1,000-op task, 53,000-63,000 at 8,000 and 99,500 (the bound) at 16,000; the Zig-side peak went 7.6 -> 47 -> 81 MB; but once drained, the live nodes were the undo history's 7,000 at every K. The one real retention (one CSSStyleProperties per element A04 read, architecture-a-hand-outs-edge-on-an-unwrapped-owner-is-a-strong-hold-until-its-teardown-ends-it.md) showed only in the census, as the one interface whose count differed between the two builds.

**Fix**: `gc_bench --batch=<K> --settle --live-types --c-alloc` on both builds, at two K: a type whose count grows with K after the drain is retention; a peak that grows with K while the census stays flat is the in-task backlog and the allocators' residue (whether 100,000 queued nodes is the right in-task bound is a separate question - V8 bounds Blink's dead DOM by its global limit, cppgc sweeping on allocation).

**Takeaway**: **Before naming a structure that grows per operation, drain the teardown queue and diff the live objects by interface between the two builds; a curve read once per page of one task measures that task's peak.**
