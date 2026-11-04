//! The joined fixture's per_test member (joined_fixture.zig).

const std = @import("std");
const runtime = @import("runtime");

test "leaves nothing" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    scope.deinit();
}

test "makes a standalone runtime and leaves it" {
    // Fine in the process_start member, a leaver here: the same line as
    // start/member.zig's test, judged by this member's row.
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
}
