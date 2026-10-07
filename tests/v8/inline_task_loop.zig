//! An event loop for a test's worker realm. Every worker realm has one
//! (runtime.WorkerRealmOptions.event_loop is required: a worker's own loop,
//! on its own thread), but a test that makes a realm on its own drives no
//! loop. This one runs what it is handed at once - the caller is at a task
//! boundary, as the hosts' paths for a realm with no loop assumed - so a test
//! sees what a bare realm did before the option was required. It keeps no
//! state, so one value serves every realm and thread.
//!
//! Not a test file: the tests of this directory import it.

const std = @import("std");
const runtime = @import("runtime");

/// The loop, for `WorkerRealmOptions.event_loop`.
pub fn eventLoop() runtime.EventLoop {
    return .{ .ptr = @ptrCast(@constCast(&anchor)), .vtable = &vtable };
}

/// What `ptr` points at: nothing is read through it.
const anchor: u8 = 0;

const vtable: runtime.EventLoop.VTable = .{
    .queueMicrotask = queueMicrotask,
    .queueTask = queueTask,
    .runMicrotasks = runMicrotasks,
    .runOnce = runOnce,
    .promiseAllocator = promiseAllocator,
};

fn queueTask(_: *anyopaque, task: runtime.EventLoopTask) void {
    task.callback(task.context);
}

fn queueMicrotask(_: *anyopaque, task: runtime.EventLoopMicrotask) void {
    task.callback(task.context);
}

fn runMicrotasks(_: *anyopaque) void {}

fn runOnce(_: *anyopaque) bool {
    return false;
}

fn promiseAllocator(_: *anyopaque) std.mem.Allocator {
    return std.heap.page_allocator;
}
