//! A sleeping worker needs the next foreground deadline and a posted wake.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const clock = @import("clock");
const ffi = @import("v8").ffi;

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}
fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}
const reporter: engine.Reporter = .{ .report = report, .host = null };

fn nextDelay(agent: *engine.Agent) ?u64 {
    if (comptime @hasDecl(engine, "nextEngineTaskDelay")) return engine.nextEngineTaskDelay(agent);
    return null;
}

fn drain(sink: *runtime.TaskSink) !void {
    var tasks: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer tasks.deinit(std.testing.allocator);
    try sink.takeAll(&tasks, std.testing.allocator);
    for (tasks.items) |task| task.run(task.data);
}

fn check() !void {
    try engine.initializeEngine(.{});
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    const sink = try runtime.TaskSink.create(std.testing.allocator);
    defer sink.release();
    defer sink.close();
    const hooks: engine.HostHooks = .{};
    var options: engine.AgentOptions = .{ .can_block = true, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator };
    if (comptime @hasField(engine.AgentOptions, "engine_task_sink")) options.engine_task_sink = sink;
    {
        const agent = try engine.createAgent(options);
        defer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://bf1.test", .create_global_object = createGlobal });
        defer engine.destroyWindowRealm(realm, .global_detached);
        while (engine.runEngineTasks(agent)) {}
        try drain(sink);
        // V8 can have its own delayed memory-reducer work queued already.
        // The waitAsync deadline below must become the next runnable task.
        try engine.runClassicScript(realm, .{ .utf8 =
            \\globalThis.finished = false;
            \\Atomics.waitAsync(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100)
            \\  .value.then(value => { finished = value === 'timed-out'; });
        }, "bf1-engine-tasks.js", null, reporter);
        const delay = nextDelay(agent);
        try std.testing.expect(delay != null);
        try std.testing.expect(delay.? <= 100 * std.time.ns_per_ms);
        try std.testing.expect(sink.hasPosted());
        try std.testing.expectEqual(@as(u32, 2), sink.refs.load(.acquire));
        const limit = clock.monotonicMillis() + 5000;
        while (true) {
            try drain(sink);
            const remaining = nextDelay(agent) orelse return error.LostWaitAsyncDeadline;
            sink.waitForWork(remaining);
            while (engine.runEngineTasks(agent)) {}
            try engine.performMicrotaskCheckpoint(agent);
            const text = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = "finished" }, "", null, std.testing.allocator, reporter);
            defer std.testing.allocator.free(text);
            if (std.mem.eql(u8, text, "true")) break;
            try std.testing.expect(clock.monotonicMillis() < limit);
        }
        try engine.performMicrotaskCheckpoint(agent);
        const text = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = "finished" }, "", null, std.testing.allocator, reporter);
        defer std.testing.allocator.free(text);
        try std.testing.expectEqualStrings("true", text);
        // A closed runner has no runnable deadline, even if V8 left work.
        ffi.v8_Isolate_CloseForegroundTasks(@ptrCast(agent));
        try std.testing.expectEqual(@as(?u64, null), nextDelay(agent));
    }
    // The agent releases its owned wake target, even with queued no-op wakes.
    try std.testing.expectEqual(@as(u32, 1), sink.refs.load(.acquire));
}

test "foreground delayed task supplies a wake and deadline, then releases its sink" {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = check();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

fn raceTeardown(comptime can_block: bool) !void {
    if (comptime @hasDecl(ffi, "v8_test_ForegroundTaskRunner")) {
        try engine.initializeEngine(.{});
        runtime.initializeRuntime(std.testing.allocator);
        defer runtime.deinitializeRuntime();
        const sink = try runtime.TaskSink.create(std.testing.allocator);
        defer sink.release();
        defer sink.close();
        const hooks: engine.HostHooks = .{};
        const agent = try engine.createAgent(.{ .can_block = can_block, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator, .engine_task_sink = sink });
        var agent_live = true;
        defer if (agent_live) engine.destroyAgent(agent);
        const runner = ffi.v8_test_ForegroundTaskRunner(@ptrCast(agent)) orelse return error.NoRunner;
        defer ffi.v8_test_TaskRunner_Release(runner);
        const Counts = struct {
            ran: std.atomic.Value(u32) = .init(0),
            dropped: std.atomic.Value(u32) = .init(0),
            first: std.atomic.Value(bool) = .init(false),
            fn run(data: ?*anyopaque) callconv(.c) void {
                const self: *@This() = @ptrCast(@alignCast(data.?));
                _ = self.ran.fetchAdd(1, .monotonic);
            }
            fn drop(data: ?*anyopaque) callconv(.c) void {
                const self: *@This() = @ptrCast(@alignCast(data.?));
                _ = self.dropped.fetchAdd(1, .monotonic);
            }
            fn post(handle: @TypeOf(runner), self: *@This()) void {
                for (0..1000) |i| {
                    ffi.v8_test_TaskRunner_Post(handle, run, drop, self, 0);
                    if (i == 0) self.first.store(true, .release);
                }
            }
        };
        var counts: Counts = .{};
        // The foreign thread holds only the runner, never an isolate pointer.
        const posting = try std.Thread.spawn(.{}, Counts.post, .{ runner, &counts });
        var joined = false;
        defer if (!joined) posting.join();
        while (!counts.first.load(.acquire)) std.Thread.yield() catch {};
        sink.waitForWork(std.time.ns_per_s);
        try std.testing.expect(sink.hasPosted());
        try std.testing.expectEqual(@as(?u64, 0), nextDelay(agent));
        engine.destroyAgent(agent);
        agent_live = false;
        const closed_wake = sink.wake.load(.acquire);
        posting.join();
        joined = true;
        // Posts after close are discarded and cannot touch the former sink.
        for (0..64) |_| ffi.v8_test_TaskRunner_Post(runner, Counts.run, Counts.drop, &counts, 0);
        try std.testing.expectEqual(closed_wake, sink.wake.load(.acquire));
        try std.testing.expectEqual(@as(u32, 0), counts.ran.load(.acquire));
        try std.testing.expectEqual(@as(u32, 1064), counts.dropped.load(.acquire));
        try std.testing.expectEqual(@as(u32, 1), sink.refs.load(.acquire));
    } else return error.NoForegroundTaskRunnerIntegration;
}

test "foreign foreground posts wake the loop and cannot outlive agent teardown" {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = raceTeardown(true);
            result.* catch return;
            result.* = raceTeardown(false);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}
