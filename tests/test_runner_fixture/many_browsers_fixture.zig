//! The many-Browsers variant's fixture: a test that assumes it is the only
//! Browser in its process, and one that assumes nothing. Run by
//! tools/test_launcher/child.zig's tests with and without the variant: with
//! it the first must fail - the busy Browser is alive beside it - and the
//! second must pass (a busy Browser that failed an iteration would fail it);
//! without it both pass. So the variant is seen to run concurrently with the
//! test, and its busy Browser to do its work cleanly.
//! Not part of any suite: build.zig compiles it, with -Dmany-browsers, only
//! for the launcher's tests.

const std = @import("std");
const runtime = @import("runtime");

test "assumes it is the only Browser in its process" {
    const io = std.testing.io;
    const at_start = runtime.BrowserScope.liveCount();
    // Two seconds of looking: a busy Browser lives through most of each of
    // its iterations.
    for (0..100) |_| {
        if (runtime.BrowserScope.liveCount() != at_start) return error.AnotherBrowserIsAlive;
        io.sleep(.fromMilliseconds(20), .awake) catch {};
    }
}

test "assumes nothing" {
    // Long enough for the busy Browser to finish iterations beside it.
    std.testing.io.sleep(.fromSeconds(3), .awake) catch {};
}
