# Architecture: A snapshot's external reference table must not depend on the optimizer

**Date**: 2026-10-02
**Lesson**: V8 names each callback in a snapshot by its index in the embedder's
external reference table, so generation and load must register the same
entries in the same order. Dropping repeated addresses made the table's length
depend on which functions the optimizer merged, and every ReleaseSafe runner
silently ran without the snapshot.

**Why**: `external_references.registerPointer` skipped an address it had
already seen. An optimized build folds identical functions (V8 calls it ICF),
so callbacks that are distinct in Debug share addresses in ReleaseSafe: the
runner's table was 8,287 entries against the (Debug) snapshot generator's
11,465. The build stamp check did its job - `initializeEngine` refused the blob
("the snapshot was made against 11465 external references and this build has
8287") - and the Browser fell back to the no-snapshot path for every realm.
Nothing failed; the ReleaseSafe runner was simply a different engine, and its
parity run with Debug measured that difference along with the undefined
behaviour it was meant to find.

**Fix**: every registration takes the next index, repeats included. V8 expects
that: its encoder keeps the first index of a repeated address ("Ignore
duplicate references. This can happen due to ICF. See
http://crbug.com/726896.", src/codegen/external-reference-encoder.cc). Pinned
in tests/v8/snapshot_test.zig.

**Takeaway**: **Anything a build writes and a different build reads - a
snapshot, its reference table, a stamp - must be a function of the source, not
of the optimizer. Read a runner's warnings in each build mode: a refused
snapshot is one line in a log, not a failure.**
