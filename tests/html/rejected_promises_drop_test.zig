//! "Notify about rejected promises" step 4 queues a global task carrying the
//! promises it will report (rejected_promises.zig, Notification). A task on
//! an event loop may never run: a dedicated worker's own loop drops every
//! task still queued when the worker closes or is terminated (HTML close()
//! and "terminate a worker": discard the worker's tasks), and a window's
//! loop drops a task whose document is not fully active. A task dropped
//! with no `drop` leaks what it carries - here the Notification record, its
//! list, and a held engine handle for each promise and reason.
//!
//! tests/html is one executable: the engine may already be started, and the
//! test's agent is made on a thread of its own, so it is that thread's host
//! agent and its end tears down only that thread's engine state.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const html = @import("html");

const allocator = std.heap.page_allocator;

/// The process-wide pieces a worker realm's platform objects need, unless a
/// file before this one started them.
fn startProcess() !void {
    if (runtime.SlabAllocator.tryGet()) |_| {} else |_| runtime.initializeRuntime(allocator);
    @import("interfaces").process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
}

/// An event loop that only collects the tasks queued on it: none runs.
const CollectingLoop = struct {
    tasks: std.ArrayListUnmanaged(runtime.EventLoopTask) = .empty,

    const vtable: runtime.EventLoop.VTable = .{
        .queueMicrotask = queueMicrotask,
        .queueTask = queueTask,
        .runMicrotasks = runMicrotasks,
        .runOnce = runOnce,
        .promiseAllocator = promiseAllocator,
    };

    fn eventLoop(self: *CollectingLoop) runtime.EventLoop {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn queueTask(ptr: *anyopaque, task: runtime.EventLoopTask) void {
        const self: *CollectingLoop = @ptrCast(@alignCast(ptr));
        self.tasks.append(allocator, task) catch @panic("out of memory");
    }

    fn queueMicrotask(_: *anyopaque, task: runtime.EventLoopMicrotask) void {
        task.callback(task.context);
    }

    fn runMicrotasks(_: *anyopaque) void {}

    fn runOnce(_: *anyopaque) bool {
        return false;
    }

    fn promiseAllocator(_: *anyopaque) std.mem.Allocator {
        return allocator;
    }
};

fn ignoreReport(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

/// V8's own count of the bytes its global handles use, for `realm`'s agent:
/// read with the realm entered, since the count is the current isolate's.
fn globalHandleBytes(realm: runtime.Context) !i64 {
    const Probe = struct {
        value: ?i64 = null,

        fn read(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const counters = engine.diagnosticCounters(allocator) catch return;
            defer allocator.free(counters);
            for (counters) |counter| {
                if (std.mem.eql(u8, counter.name, "global_handle_bytes")) self.value = counter.value;
            }
        }
    };
    var probe: Probe = .{};
    try engine.runInRealm(realm, Probe.read, &probe);
    return probe.value orelse error.NoCounter;
}

const Outcome = struct {
    queued: usize = 0,
    had_drop: bool = false,
    released: bool = false,
    failed: ?anyerror = null,
};

fn body(outcome: *Outcome) void {
    run(outcome) catch |err| {
        outcome.failed = err;
    };
}

fn run(outcome: *Outcome) !void {
    const agent = try engine.createAgent(.{
        .can_block = true,
        .from_snapshot = false,
        .hooks = &html.rejected_promises.hooks,
        .allocator = allocator,
    });
    defer engine.destroyAgent(agent);

    var loop: CollectingLoop = .{};
    defer loop.tasks.deinit(allocator);
    const made = try engine.createWorkerRealm(agent, &.{
        .url = "http://web-platform.test:8000/workers/w.js",
        .timer = null,
        .event_loop = loop.eventLoop(),
        .allocator = allocator,
    });
    defer engine.destroyWorkerRealm(made.realm, null, null);
    // What the worker host's realm end does: release the global's
    // bookkeeping while the agent lives.
    defer html.rejected_promises.forgetGlobal(made.global_scope);

    // An unhandled rejection: the checkpoint after the script ("clean up
    // after running script") notifies, and queues the global task.
    try engine.runClassicScript(made.realm, .{ .utf8 = "Promise.reject(new Error('never handled'));" }, "w.js", null, .{ .report = ignoreReport });
    outcome.queued = loop.tasks.items.len;
    if (outcome.queued != 1) return;
    const task = loop.tasks.items[0];
    const drop = task.drop orelse return;
    outcome.had_drop = true;

    // The worker closes: the loop drops the task unrun. What it held -
    // the promise and its reason - is released.
    const before = try globalHandleBytes(made.realm);
    drop(task.context);
    const after = try globalHandleBytes(made.realm);
    outcome.released = after < before;
}

test "a notification of rejected promises queued on a loop carries a drop that releases its promises" {
    try startProcess();
    var outcome: Outcome = .{};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, body, .{&outcome});
    thread.join();
    if (outcome.failed) |err| return err;
    try testing.expectEqual(@as(usize, 1), outcome.queued);
    try testing.expect(outcome.had_drop);
    try testing.expect(outcome.released);
}
