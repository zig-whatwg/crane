# Testing: A test file at the top of tests/ is never built

**Date**: 2026-10-18
**Lesson**: `zig build test` builds `tests/<dir>/` directories; a `*_test.zig` directly under `tests/` is compiled by nothing unless build.zig names it, so it can rot for a year while it looks like coverage.

**Why**: `addTestFilesFromDir` is called once per test directory (`tests/dom`, `tests/streams`, `tests/v8` ...) and walks only that directory. No call walks `tests/` itself, and only one top-level file, `tests/browser_document_test.zig`, is named in build.zig. Zig does not analyse a file nothing imports, so a stale API call in such a file is never an error.

**What Happened**: Lane impls6 (impls boundary, tests) found `tests/streams_functional_test.zig` holding 10 references into the ReadableStream and reader impls. It had been at the top of tests/ since 2025-11-23 and called `interfaces.ReadableStream.call_constructor(allocator, ctx, &source, strategy)`, a signature the constructor lost long ago (it takes `ctx` and two `webidl.Opt` arguments now). It never compiled, so its five cases - enqueue and read, desiredSize, error propagation, cancel, enqueue after close - asserted nothing; WPT's streams/readable-streams/ files cover each of them. The integrator had it deleted. Fifteen more top-level files are in the same state (streams_abort, _async_iteration, _basic, _byob, _cancel, _from, _pipe, _structured_clone, _transfer, _transform, main, root, tmp_offset, url_api, webidl_inheritance, webidl_ptrcast).

**Fix**:
1. Before converting, porting or counting a test, check that build.zig builds it: `grep -c <file name> build.zig` for a top-level file, or that it sits under a `tests/<dir>/` that `addTestFilesFromDir` walks.
2. A live case moves into a built directory (and must go red once there); a dead file whose cases a built test or WPT covers is deleted.

**Takeaway**: **A test file nothing builds is not a test: check that build.zig reaches it before trusting, converting or counting it.**
