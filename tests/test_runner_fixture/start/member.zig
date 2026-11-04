//! The joined fixture's process_start member (joined_fixture.zig).

const std = @import("std");
const runtime = @import("runtime");

test "makes the standalone runtime once, as its suite's test start does" {
    // tests/v8/test_process.zig `start`: the process's one standalone runtime,
    // made by whichever test runs first, never ended. From the page
    // allocator, so that only the state check sees it.
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
}
