//! The stub platform backend's media handles are each stub context's own: a
//! handle counter is state of the context its vtable functions are handed
//! (`OpaquePtr`, a StubContext), never of the process. Process-wide counters
//! numbered every context's handles together, so a second context's first
//! media source was not 1, and two tests running in one process saw each
//! other's counts (lane gstate3, class X).
const std = @import("std");
const testing = std.testing;

const stub = @import("platform").stub_platform_backend;
const StubContext = stub.StubContext;
const media = stub.stub_media_vtable;

fn expectHandle(expected: u64, handle: anytype) !void {
    try testing.expectEqual(expected, @as(u64, @intCast(handle)));
}

test "each stub context numbers its own media handles from 1" {
    var first = StubContext.init(testing.allocator);
    defer first.deinit();
    var second = StubContext.init(testing.allocator);
    defer second.deinit();

    try expectHandle(1, media.createMediaSource(&first));
    try expectHandle(2, media.createMediaSource(&first));
    // Another context's numbering is untouched by the first's.
    try expectHandle(1, media.createMediaSource(&second));

    const mime = "video/webm";
    try expectHandle(1, media.addSourceBuffer(&first, 1, mime.ptr, mime.len));
    try expectHandle(1, media.addSourceBuffer(&second, 1, mime.ptr, mime.len));

    const key_system = "org.w3.clearkey";
    const keys = media.createMediaKeys(&first, key_system.ptr, key_system.len);
    try expectHandle(1, keys);
    try expectHandle(1, media.createMediaKeys(&second, key_system.ptr, key_system.len));
    try expectHandle(1, media.createSession(&first, keys, 0));
    try expectHandle(1, media.createSession(&second, keys, 0));

    try expectHandle(1, media.call_getUserMedia(&first, true, false));
    try expectHandle(1, media.call_getUserMedia(&second, true, false));
}
