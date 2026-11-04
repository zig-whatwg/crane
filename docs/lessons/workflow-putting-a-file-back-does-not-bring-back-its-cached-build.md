# Workflow: Putting a file back does not bring back its cached build

**Date**: 2026-11-03
**Lesson**: Zig keeps one cache manifest per compile step - the latest - so after a change and its revert, every compile that saw the change rebuilds once more: a "one test file changed" measurement taken after a "one source file changed" step measured the whole source rebuild again (1,842 s, not minutes).

**Why**: A compile step's manifest is found by a hash of the step's own inputs (its arguments, options, the names of its root files), not of the files' contents; the manifest then lists every file the compile read, with its hash. A changed file makes the lookup a miss, the compile runs, and the manifest is REWRITTEN with the new hashes and output. Reverting the file makes the next lookup a miss again - against the rewritten manifest - so the artifacts of the original build, though still on disk, are never found. The cache is not content-addressed history.

**What Happened**: Lane onebin1's window measured, from one cold cache: (c) a comment appended to src/dom/boundary_points.zig, then the file put back, then (d) a comment appended to one tests/dom file. NEW main's (d) ran the same 6,038 tests as (c) and took 1,842 s, against 1,621 s for (c): every executable that imports `dom` rebuilt in (d) for the revert, not just tests-dom for its test file.

**Fix**: Order incremental measurements so that no step follows a revert of a file a later step's compiles read: (d) before (c), since (c)'s change rebuilds everything (d)'s did. To measure two independent edits each from the cold state, give each its own copy of the cold cache (cp -R before the first edit) - never "edit, measure, revert, edit".

**Takeaway**: **A revert is another change to Zig's cache: measure each incremental edit from a cache that never saw an earlier one.**
