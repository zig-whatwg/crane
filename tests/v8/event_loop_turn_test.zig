//! One turn of `V8EventLoop.runOnceBlocking` runs the tasks that were queued
//! when it began, and no more. A task one of them queues waits for the next
//! turn.
//!
//! The loop used to drain until the queue was empty, so a task that queues a
//! task - a frame whose load handler navigates the frame, whose next load
//! runs the handler again - kept a single call from ever returning, and the
//! caller's deadline, checked between calls, never came round. The WPT
//! runner's per-file ceiling is that deadline: such a file hung the process
//! until the supervisor's stall watchdog killed it, 150 seconds later.

const std = @import("std");
const test_process = @import("test_process.zig");
const v8 = @import("v8");
const ffi = v8.ffi;

/// A live isolate with an entered context: a turn performs a microtask
/// checkpoint, which needs one. The test's own agent's (test_agent), ended
/// with the test.
var test_isolate: ?*ffi.Isolate = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
}

fn isolate() !*ffi.Isolate {
    const i = try test_agent.open(.{});
    if (test_isolate == null) test_isolate = i;
    return test_isolate.?;
}

const Chain = struct {
    loop: *v8.V8EventLoop,
    /// Tasks still to queue, each from the one before.
    remaining: usize,
    ran: usize = 0,
};

fn step(context: ?*anyopaque) void {
    const chain: *Chain = @ptrCast(@alignCast(context.?));
    chain.ran += 1;
    if (chain.remaining == 0) return;
    chain.remaining -= 1;
    chain.loop.eventLoop().queueTask(.{ .callback = &step, .context = chain });
}

test "a task queued by a task waits for the next turn" {
    defer test_agent.close();
    var loop = v8.V8EventLoop.initWithoutTimers(try isolate(), std.testing.allocator);
    defer loop.deinit();

    var chain: Chain = .{ .loop = &loop, .remaining = 2 };
    loop.eventLoop().queueTask(.{ .callback = &step, .context = &chain });

    _ = loop.runOnceBlocking(0);
    try std.testing.expectEqual(@as(usize, 1), chain.ran);
    _ = loop.runOnceBlocking(0);
    try std.testing.expectEqual(@as(usize, 2), chain.ran);
    _ = loop.runOnceBlocking(0);
    try std.testing.expectEqual(@as(usize, 3), chain.ran);
    // The chain is spent: nothing is left for another turn.
    try std.testing.expect(!loop.hasPendingWork());
}

test "a task that always queues another cannot keep a turn from returning" {
    defer test_agent.close();
    var loop = v8.V8EventLoop.initWithoutTimers(try isolate(), std.testing.allocator);
    defer loop.deinit();

    var chain: Chain = .{ .loop = &loop, .remaining = std.math.maxInt(usize) };
    loop.eventLoop().queueTask(.{ .callback = &step, .context = &chain });

    // Returning at all is the assertion; before, this call never did.
    _ = loop.runOnceBlocking(0);
    try std.testing.expectEqual(@as(usize, 1), chain.ran);
    try std.testing.expect(loop.hasPendingWork());
}

test "every task queued before a turn runs in it" {
    defer test_agent.close();
    var loop = v8.V8EventLoop.initWithoutTimers(try isolate(), std.testing.allocator);
    defer loop.deinit();

    var chains: [3]Chain = undefined;
    for (&chains) |*chain| {
        chain.* = .{ .loop = &loop, .remaining = 0 };
        loop.eventLoop().queueTask(.{ .callback = &step, .context = chain });
    }

    _ = loop.runOnceBlocking(0);
    for (chains) |chain| try std.testing.expectEqual(@as(usize, 1), chain.ran);
}
