//! `BrowserScope.liveCount`: every BrowserScope - each Browser's and the
//! standalone runtime's - from its `init` to its `deinit`. The Crane test
//! runner (tests/test_runner/) reads it before and after every test: a test
//! that leaves a Browser alive fails by name (the approved test plan,
//! tmp/plans/test-architecture-recommendation.md section 3; Blink's leak
//! detector reads its instance counters the same way).

const std = @import("std");
const runtime = @import("runtime");

test "liveCount counts each scope from its init to its deinit" {
    const before = runtime.BrowserScope.liveCount();

    var first = runtime.BrowserScope.init(std.testing.allocator);
    try std.testing.expectEqual(before + 1, runtime.BrowserScope.liveCount());
    var second = runtime.BrowserScope.init(std.testing.allocator);
    try std.testing.expectEqual(before + 2, runtime.BrowserScope.liveCount());

    second.deinit();
    try std.testing.expectEqual(before + 1, runtime.BrowserScope.liveCount());
    first.deinit();
    try std.testing.expectEqual(before, runtime.BrowserScope.liveCount());
}

test "a scope that made objects and tables is counted until its end" {
    const before = runtime.BrowserScope.liveCount();
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    // Its arena in use, as a Browser's is.
    _ = try scope.arena.alloc(u8, 64);
    try std.testing.expectEqual(before + 1, runtime.BrowserScope.liveCount());
    scope.deinit();
    try std.testing.expectEqual(before, runtime.BrowserScope.liveCount());
}

test "the standalone runtime's scope is one of them" {
    const before = runtime.BrowserScope.liveCount();
    const previous = runtime.BrowserScope.standalone();
    runtime.initializeRuntime(std.testing.allocator);
    try std.testing.expectEqual(before + 1, runtime.BrowserScope.liveCount());
    runtime.deinitializeRuntime();
    runtime.BrowserScope.setStandalone(previous);
    try std.testing.expectEqual(before, runtime.BrowserScope.liveCount());
}
