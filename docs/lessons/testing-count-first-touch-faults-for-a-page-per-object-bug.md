# Testing: A page-per-object bug shows as minor page faults - not as mappings, and not as footprint under ThreadSanitizer

**Date**: 2026-11-23
**Lesson**: To prove that something no longer takes a page per object, count the process's minor page faults (getrusage `ru_minflt`) over a batch against a control batch. Mapping counts and the footprint both miss it or blur it.

**Why**: Each object on its own fresh page costs at least one first-touch fault, whatever the OS and whatever the sanitizer.
- **Mapping counts don't see it.** Linux merges adjacent anonymous mmaps into one mapping, and Zig's PageAllocator maps each page right after the last one. XNU coalesces anonymous regions the same way.
- **Footprint blurs it under ThreadSanitizer.** ThreadSanitizer commits its shadow and metadata memory in multi-megabyte steps, so one batch can read +0 and the next +13 MiB for the same work.

**What Happened**: Lane leak3 fixed an addEventListener `signal` record that took one std.heap.page_allocator page per listener. The first test read the footprint of 4,000 kept listeners against a no-signal control. Natively that was exact: red +16 MiB, green +1 MiB.
- Under `-Dsanitize-thread`, test-verify failed on green: +13,620 KiB with a signal, +0 KiB on the control.
- The integrator asked for a `/proc/self/maps` count instead, expecting about +4,000 in red. The red runs on the unfixed code added only +11 to +120 mappings, because the kernel merged the pages.
- Minor faults over the control separated the two cleanly. Plain build: red +4,042, green +470. ThreadSanitizer: red +12,406, green +1,628 to +1,805. The counts repeated exactly from run to run.

**Fix** (tests/html/leak3_signal_listener_record_test.zig):
1. Read `std.posix.getrusage(std.posix.rusage.SELF).minflt` before and after the batch, and run the same batch without the subject as a control. Measure the second batch of each kind, so the first one settles the engine's young generation and the lists' growth.
2. Assert the extra faults against a limit set from measured red and green figures. Under ThreadSanitizer every heap page touched also faults its shadow pages, so its limit is higher (`if (builtin.sanitize_thread)`).
3. Keep any footprint assertion to `!builtin.sanitize_thread`, and print mapping counts rather than asserting them.

**Takeaway**: **A page per object is a first-touch fault per object: assert on `ru_minflt` against a control batch, which holds in every build, never on mappings, which merge.**
