//! Async XHR can start on a native host's event loop in a realm with no
//! script engine context - its agent's fetches are the host's (AgentHost.
//! fetches), as a Browser's or a worker's are. Its owner stays alive when the
//! fetch's callable-realm check rejects it.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const AgentHost = @import("html_core").agent_host.AgentHost;

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
            // The native host's agent: its fetches are what the XHR starts
            // on. The realm has no engine context of its own.
            try engine.initializeEngine(.{});
            var agent_host = AgentHost.init(allocator);
            defer agent_host.deinit();
            const agent = try engine.createAgent(.{
                .can_block = false,
                .from_snapshot = false,
                .allocator = allocator,
                .hooks = &.{},
                .host = &agent_host,
            });
            defer engine.destroyAgent(agent);
            const fetches = &agent_host.fetches;
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
            context.agent = agent;
            try std.testing.expect(!context.hasEngine());
            const request = try interfaces.XMLHttpRequest.call_constructor(&context);
            defer interfaces.XMLHttpRequest.deinit(request);
            const before = fetches.inFlight();
            try interfaces.XMLHttpRequest.call_open(request, "GET", "http://127.0.0.1:65533/pending");
            try interfaces.XMLHttpRequest.call_send(request, .{ .was_passed = false, .value = undefined });
            try std.testing.expectEqual(before + 1, fetches.inFlight());
            switch (self.scenario) {
                .sweep => try std.testing.expect(fetches.sweep()),
                .discard => @import("dom").document_fetches.abortAll(&context),
            }
            try std.testing.expectEqual(before, fetches.inFlight());
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
