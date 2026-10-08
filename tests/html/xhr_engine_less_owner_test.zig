//! Async XHR can start on a native host's event loop without a script engine.
//! Its owner stays alive when the fetch's callable-realm check rejects it.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const async_fetch = @import("fetch").algorithms.async_fetch;
const scheduler = @import("fetch").network.scheduler;

/// Collect native deliveries without executing script. A queued payload keeps
/// its independent hold until this host drops it during ordinary teardown.
const CollectingLoop = struct {
    allocator: std.mem.Allocator,
    tasks: std.ArrayList(runtime.EventLoopTask) = .empty,

    fn eventLoop(self: *@This()) runtime.EventLoop {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn deinit(self: *@This()) void {
        while (self.tasks.items.len != 0) {
            const task = self.tasks.orderedRemove(0);
            if (task.drop) |drop| drop(task.context);
        }
        self.tasks.deinit(self.allocator);
    }

    fn queue(context: *anyopaque, task: runtime.EventLoopTask) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.tasks.append(self.allocator, task) catch {
            if (task.drop) |drop| drop(task.context);
        };
    }
    fn microtask(_: *anyopaque, task: runtime.EventLoopMicrotask) void {
        task.callback(task.context);
    }
    fn flush(_: *anyopaque) void {}
    fn once(_: *anyopaque) bool {
        return false;
    }
    fn promiseAllocator(context: *anyopaque) std.mem.Allocator {
        const self: *@This() = @ptrCast(@alignCast(context));
        return self.allocator;
    }
    const vtable: runtime.EventLoop.VTable = .{
        .queueTask = queue,
        .queueMicrotask = microtask,
        .runMicrotasks = flush,
        .runOnce = once,
        .promiseAllocator = promiseAllocator,
    };
};

const Scenario = enum { sweep, discard };

fn check(scenario: Scenario) !void {
    const Run = struct {
        scenario: Scenario,
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(self: *@This()) !void {
            const allocator = std.testing.allocator;
            interfaces.process_hooks.startHooksForTest();
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            defer scheduler.endIdleThreadScheduler();
            const timers = try runtime.native_timer.NativeTimerManager.init(allocator);
            defer timers.deinit();
            var loop: CollectingLoop = .{ .allocator = allocator };
            var context = try runtime.ContextData.init(allocator, .{
                .timer = timers.timerInterface(),
                .event_loop = loop.eventLoop(),
            });
            defer {
                loop.deinit();
                context.deinit();
            }
            try std.testing.expect(!context.hasEngine());
            const request = try interfaces.XMLHttpRequest.call_constructor(&context);
            defer interfaces.XMLHttpRequest.deinit(request);
            const before = async_fetch.inFlight();
            try interfaces.XMLHttpRequest.call_open(request, "GET", "http://127.0.0.1:65533/pending");
            try interfaces.XMLHttpRequest.call_send(request, .{ .was_passed = false, .value = undefined });
            try std.testing.expectEqual(before + 1, async_fetch.inFlight());
            switch (self.scenario) {
                .sweep => try std.testing.expect(async_fetch.sweep()),
                .discard => @import("dom").document_fetches.abortAll(&context),
            }
            try std.testing.expectEqual(before, async_fetch.inFlight());
            // A still-live native XHR can be opened again after its fetch
            // is swept or discarded. This follows a freed PendingFetch on
            // a path that confuses native ownership with realm callability;
            // exercise the public operation and ordinary owner teardown.
            try interfaces.XMLHttpRequest.call_open(request, "GET", "http://127.0.0.1:65533/replacement");
            try std.testing.expectEqual(@as(u16, 1), try interfaces.XMLHttpRequest.get_readyState(request));
        }
    };
    var run: Run = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "engine-less asynchronous XHR clears native pending link when swept" {
    try check(.sweep);
}

test "engine-less document discard clears the still-live XHR pending link" {
    try check(.discard);
}
