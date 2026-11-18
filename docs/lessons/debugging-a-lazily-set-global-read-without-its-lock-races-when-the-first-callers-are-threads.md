# Debugging: A lazily set global read without its lock races when the first callers are threads

**Date**: 2026-11-17
**Lesson**: A process-wide value that "the entry point sets before any thread exists" but also sets itself lazily on first use must publish itself with release/acquire order, or its lazy path is a data race the first time two threads ask at once.

**Why**: `src/platform/host.zig` kept the process `std.Io` in a plain optional, read without the lock in `io()` and written under the lock by `init`/`adopt` - correct while the entry point (`host.adopt` in main) sets it first. Every test executable has no such entry point, so `io()`'s lazy `init` ran on whichever thread asked first; two threads asking at once read the optional while the other wrote it.

**What Happened**: ThreadSanitizer failed every lane gate's Linux platform step (`zig build test -Dspec=platform -Dsanitize-thread`) through tests/wpt_runner/wpt_server.zig's "two runners starting together spawn one server between them" - host.zig:123 (`if (cached_io) |i| return i;`) against :63 (`cached_io = threaded.?.io();`). Two lanes (mp1, mp2) met it and carried it as main's known failure. It looked like a test problem; it was the module's contract ("set before any other thread exists") holding only for one kind of process.

**Fix**: double-checked initialisation, the writers unchanged (they still take the mutex): the value is written, then a `ready` flag is stored with `.release`; the reader loads the flag with `.acquire` and reads the value only when it is set (`Published` in host.zig). Same variable, same count and class in the global-state inventory (`lint-global-state -- --update` refreshes its declaration hash). The red test is tests/platform/bugs1_host_io_first_use_test.zig: eight threads ask first at once - red under `-Dsanitize-thread` in a process where nobody asked before (test-verify's batched run, `-Dtest-filter`), green after.

**Takeaway**: **"Set once at the entry point" is a contract the lazy path breaks: if a global may be set on first use, publish it (write, then a release store of a flag; an acquire load before the read) - and test it in a process where nothing set it yet, under ThreadSanitizer.**
