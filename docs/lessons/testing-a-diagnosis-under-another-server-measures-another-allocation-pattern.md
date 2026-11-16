# Testing: A diagnosis under another server measures another allocation pattern - run the page under the benchmark's own server

**Date**: 2026-11-16
**Lesson**: The sizes a fetched body arrives in are set by how the server writes it, so a diagnosis of a benchmark row's memory runs the page under the benchmark's own server, and prints the sizes first.

**Why**: A stream's chunks are as large as what one socket read returns, and a decoded body's pieces follow the encoded pieces. A server that writes 64 KiB at a time from Python and one that writes the file from Zig give the engine different reads, different ArrayBuffer sizes, and so a different path through a size-class allocator. A figure measured under the stand-in explains the stand-in.

**What Happened**: Lane ab1 looked for 27 MB that `fetch.loopback-gzip` counted above main. The first look used lane mem2's trace driver, which has its own Python server made to answer as `perf_bench`'s does. Under it the gzip body arrived as two pieces, 944,693 and 103,890 bytes, the tip read 118-122 MB, and the whole-chunk recommit explained 4 MB. Under `perf_bench serve` the same body arrived as ONE piece of 1,048,583 bytes - a run of two chunks in the tip's allocator - the tip read 139-142 MB as it had in the cost window, and the same mechanism explained 20.2 MB. The first look alone would have sent the lane after 20 MB that were not in its measurement.

**Fix**:
1. Before reading memory in a diagnosis run, check that the run reproduces the figure being diagnosed (here 118-122 MB against the window's 137-142: not the same run).
2. Serve the page with the benchmark's own server (`perf_bench serve --root=<dir>`), and reach the mark from inside the page (a last workload that prints a line the driver waits for) when the server gives no hook.
3. Print what the allocator sees - each piece's length and its buffer's byte length - before theorising about classes and runs.

**Takeaway**: **A stand-in server is a different workload for an allocator: reproduce the figure first, under the benchmark's own server, and print the sizes.**
