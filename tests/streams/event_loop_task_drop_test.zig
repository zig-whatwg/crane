//! `Task.drop`: a task still queued when its loop is torn down never runs, so
//! the loop hands its context back to be freed instead of leaking it.
//!
//! `std.testing.allocator` is the measurement: a context the loop forgot is a
//! leak, and the test fails on it.

const std = @import("std");
const event_loop = @import("streams_event_loop");
const TestEventLoop = @import("streams_test_event_loop").TestEventLoop;

const Payload = struct {
    allocator: std.mem.Allocator,
    ran: *bool,
    dropped: *bool,
};

fn runPayload(context: ?*anyopaque) void {
    const payload: *Payload = @ptrCast(@alignCast(context.?));
    payload.ran.* = true;
    payload.allocator.destroy(payload);
}

fn dropPayload(context: ?*anyopaque) void {
    const payload: *Payload = @ptrCast(@alignCast(context.?));
    payload.dropped.* = true;
    payload.allocator.destroy(payload);
}

test "TestEventLoop.deinit drops a task that never ran" {
    const allocator = std.testing.allocator;
    var ran = false;
    var dropped = false;

    var loop = TestEventLoop.init(allocator);
    const payload = try allocator.create(Payload);
    payload.* = .{ .allocator = allocator, .ran = &ran, .dropped = &dropped };
    loop.eventLoop().queueTask(.{ .callback = &runPayload, .context = payload, .drop = &dropPayload });
    loop.deinit();

    try std.testing.expect(!ran);
    try std.testing.expect(dropped);
}

test "a task that runs is not dropped as well" {
    const allocator = std.testing.allocator;
    var ran = false;
    var dropped = false;

    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();
    const payload = try allocator.create(Payload);
    payload.* = .{ .allocator = allocator, .ran = &ran, .dropped = &dropped };
    loop.eventLoop().queueTask(.{ .callback = &runPayload, .context = payload, .drop = &dropPayload });
    _ = loop.eventLoop().runOnce();

    try std.testing.expect(ran);
    try std.testing.expect(!dropped);
}

test "Task.drop defaults to null, so existing tasks own nothing" {
    const task: event_loop.Task = .{ .callback = &runPayload, .context = null };
    try std.testing.expect(task.drop == null);
}
