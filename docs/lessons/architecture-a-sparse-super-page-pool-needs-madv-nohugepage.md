# Architecture: A sparse pool of spans in 2 MiB super pages needs MADV_NOHUGEPAGE, or THP charges a whole huge page per touched span

**Date**: 2026-11-10
**Lesson**: On a Linux host whose transparent huge pages are `always` (or a range advised `MADV_HUGEPAGE`), a read-write region committed one 2 MiB super page at a time takes a 2 MiB huge page at the first touch of each super page, whatever small span was written; khugepaged also re-collapses spans the allocator decommitted. Mark the pool `MADV_NOHUGEPAGE` once, at reservation: the advice excludes it in every mode and holds through later mprotects.

**Why**: THP backs an aligned 2 MiB extent of an eligible anonymous VMA with one huge page on its first fault, and with the default `max_ptes_none` (511) khugepaged collapses an extent that has a single resident page (Linux v7.0 transhuge.rst). A class-stable node pool is sparse by design: a few live 16 KiB spans per super page.

**What Happened**: The oss review's probe P3 measured 512 kB of live spans in 32 super pages at +65,536 kB under emulated `always`, and khugepaged regrowing decommitted spans to +64 MiB within 45 s; server1 runs `madvise`, so the plan's RSS figures never saw it. Lane h1's red test (tests/platform/h1_address_space_test.zig, "the node cage takes no transparent huge pages") forces `MADV_HUGEPAGE` on a range, then labels it `.node_cage`, commits 32 super pages and touches one span each: AnonHugePages 65,536 kB without the label's `MADV_NOHUGEPAGE` (server1, Linux 7.0, `enabled = always [madvise] never`), 0 with it.

**Fix**: kit/posix's `labelAddressSpace` / `reserveAddressSpace` apply `MADV_NOHUGEPAGE` to every range labelled `.node_cage`. The objects and bytes pools keep the system's setting until a measurement shows whether large heaps gain from THP (oss R4).

**Takeaway**: **A sparse pool must opt out of transparent huge pages explicitly; the host you measure on may be `madvise`, but the host that runs Crane may be `always`.**
