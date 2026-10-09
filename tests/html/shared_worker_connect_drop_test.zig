//! The SharedWorker constructor's step 11 (`worker_host.connectSharedWorker`)
//! gives the SharedWorker pending activity until the shared worker manager's
//! steps end, and the steps' task ends it: when it runs, or when its loop
//! drops it. A loop can drop the task before `queueTask` returns - a window
//! loop that cannot allocate the queue entry, a closing worker's loop - so
//! the hold must be taken before the task is handed over. Taken after, the
//! drop's release came first and the hold was never released: the
//! SharedWorker stayed uncollectable until its realm ended.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const html = @import("html");
const dom = @import("dom");

/// An event loop that drops every task before `queueTask` returns, as the
/// window loop does when appending the task fails.
const DroppingLoop = struct {
    dropped: usize = 0,

    fn queueTask(ptr: *anyopaque, task: runtime.EventLoopTask) void {
        const self: *DroppingLoop = @ptrCast(@alignCast(ptr));
        self.dropped += 1;
        if (task.drop) |drop| drop(task.context);
    }
    fn queueMicrotask(_: *anyopaque, _: runtime.EventLoopMicrotask) void {}
    fn runMicrotasks(_: *anyopaque) void {}
    fn runOnce(_: *anyopaque) bool {
        return false;
    }
    fn promiseAllocator(_: *anyopaque) std.mem.Allocator {
        return testing.allocator;
    }
    const vtable: runtime.EventLoop.VTable = .{
        .queueTask = queueTask,
        .queueMicrotask = queueMicrotask,
        .runMicrotasks = runMicrotasks,
        .runOnce = runOnce,
        .promiseAllocator = promiseAllocator,
    };
};

/// The SharedWorker's steps: never reached, since the task never runs.
const unreachable_steps: html.worker_host.OwnerSteps = .{
    .error_reported = struct {
        fn f(_: *runtime.Instance, _: *const html.worker_host.ErrorReport.Info) void {
            unreachable;
        }
    }.f,
    .start_failed = struct {
        fn f(_: *runtime.Instance) void {
            unreachable;
        }
    }.f,
    .ended = struct {
        fn f(_: *runtime.Instance) void {
            unreachable;
        }
    }.f,
};

fn body() !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const ctx = page.realm orelse return error.NoPageRealm;
    if (!ctx.hasEngine()) return error.PageRealmHasNoEngine;

    // The object given pending activity: a platform object of the page's
    // realm that script has seen, and nothing else holds once `held` goes.
    // (The steps only ever read its slab generation and its hold.)
    const worker = try interfaces.HTMLDivElement.init(testing.allocator, ctx);
    const generation = runtime.SlabAllocator.generationOf(worker);
    const held = try engine.retainValue(ctx, .{ .instance = worker });
    if (!engine.hasWrapper(worker)) return error.NotWrapped;

    // The outside settings' realm, whose loop drops the manager's steps.
    var loop: DroppingLoop = .{};
    var owner_realm = try runtime.ContextData.init(testing.allocator, .{
        .event_loop = .{ .ptr = &loop, .vtable = &DroppingLoop.vtable },
    });
    defer owner_realm.deinit();

    // The inside end the steps take; its partner is the constructor's.
    const channel = try dom.port_channels.Channel.create(testing.allocator);
    channel.end(0).discard();

    try html.worker_host.connectSharedWorker(.{
        .worker = worker,
        .steps = &unreachable_steps,
        .owner_realm = &owner_realm,
        .url = "https://web-platform.test:8443/workers/w.js",
        .origin = "https://web-platform.test:8443",
        .name = "",
        .worker_type = .classic,
        .credentials = .same_origin,
        .inside_end = channel.end(1),
    });
    try testing.expectEqual(@as(usize, 1), loop.dropped);

    // The steps ended with their drop: no pending activity is left, and
    // once script lets go the collector frees the object.
    held.release();
    engine.requestGarbageCollection(page.agent);
    engine.requestGarbageCollection(page.agent);
    if (runtime.SlabAllocator.generationOf(worker) == generation) return error.SharedWorkerStillHeldAfterItsStepsDropped;
}

test "a SharedWorker's connect steps dropped as they are queued leave it no pending activity" {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    // A Browser of its own on a thread of its own (a test directory is one
    // process: AGENTS.md "A test directory is one executable").
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
