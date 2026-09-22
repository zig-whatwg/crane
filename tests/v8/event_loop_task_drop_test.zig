//! `V8EventLoop.deinit` hands every still-queued task's context to its
//! `Task.drop`: a task queued in the last turn before a page ends never runs,
//! and without the hook whatever it carried leaks.
//!
//! Neither `queueTask` nor `deinit` calls into V8 - one appends to a Zig list,
//! the other frees it - so the loop is built around an isolate pointer that is
//! never dereferenced, and the test needs no V8 platform.

const std = @import("std");
const v8 = @import("v8");

const Payload = struct {
    allocator: std.mem.Allocator,
    dropped: *bool,
};

fn neverRuns(context: ?*anyopaque) void {
    _ = context;
    unreachable;
}

fn dropPayload(context: ?*anyopaque) void {
    const payload: *Payload = @ptrCast(@alignCast(context.?));
    payload.dropped.* = true;
    payload.allocator.destroy(payload);
}

test "V8EventLoop.deinit drops a task that never ran" {
    const allocator = std.testing.allocator;
    var dropped = false;

    const unused_isolate: *v8.ffi.Isolate = @ptrFromInt(0x1000);
    var loop = v8.V8EventLoop.initWithoutTimers(unused_isolate, allocator);
    const payload = try allocator.create(Payload);
    payload.* = .{ .allocator = allocator, .dropped = &dropped };
    loop.eventLoop().queueTask(.{ .callback = &neverRuns, .context = payload, .drop = &dropPayload });
    loop.deinit();

    try std.testing.expect(dropped);
}

test "V8EventLoop.deinit leaves a task without a drop alone" {
    var loop = v8.V8EventLoop.initWithoutTimers(@ptrFromInt(0x1000), std.testing.allocator);
    loop.eventLoop().queueTask(.{ .callback = &neverRuns, .context = null });
    loop.deinit();
}
