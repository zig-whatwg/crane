//! ReadableStreamPipeTo must finish enqueue before invoking author write code.
//! Exercise the real bindings in a fresh thread, with leak-checked allocations.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");

const Trial = struct {
    result: anyerror!void = {},
    drop_pending: bool = false,
    reentrant_abort: bool = false,

    fn run(self: *Trial) void {
        self.result = exercise(self.drop_pending, self.reentrant_abort);
    }

    fn makeWindow(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(testing.allocator, realm) catch null;
    }

    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("xs1 pipe fixture: {s}\n", .{info.message});
    }

    fn script(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
        const actual = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "xs1-pipe.js", null, testing.allocator, .{ .report = report });
        defer testing.allocator.free(actual);
        try testing.expectEqualStrings(expected, actual);
    }

    fn recordWrite(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const writes: *usize = @ptrCast(@alignCast(data.?));
        writes.* += 1;
        return runtime.JSValue.jsUndefined;
    }

    const ControllerCall = struct {
        controller: *runtime.Instance,
        chunk: runtime.JSValue = runtime.JSValue.jsUndefined,
        result: anyerror!void = {},

        fn enqueue(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.result = interfaces.ReadableStreamDefaultController.call_enqueue(self.controller, .{ .was_passed = true, .value = self.chunk });
        }

        fn close(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.result = interfaces.ReadableStreamDefaultController.call_close(self.controller);
        }
    };

    fn exercise(drop_pending: bool, reentrant_abort: bool) !void {
        try engine.initializeEngine(.{});
        runtime.initializeRuntime(testing.allocator);
        defer runtime.deinitializeRuntime();
        interfaces.process_hooks.startHooksForTest();
        var scope = runtime.BrowserScope.init(testing.allocator);
        defer scope.deinit();
        const hooks: engine.HostHooks = .{};
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &hooks,
            .allocator = testing.allocator,
        });
        defer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = testing.allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://xs1.test",
            .browser_scope = &scope,
            .create_global_object = makeWindow,
        });
        defer engine.destroyWindowRealm(realm, .global_detached);
        var writes: usize = 0;
        const write_hook: engine.BuiltinFunction = .{ .steps = recordWrite, .data = &writes };
        try engine.defineBuiltinFunction(realm, "xs1RecordWrite", 0, &write_hook);

        if (reentrant_abort) {
            // Engine-source majority, not a measured browser result:
            // Blink core/streams/pipe_to_engine.cc ReadRequestChunkStepsBody
            // and WriteQueuedChunks; WebKit Modules/streams/
            // StreamPipeToUtilities.cpp doWrite and waitForPendingReadAndWrite.
            // They install the first write promise after author code returns,
            // so reentrant abort can cancel before that write settles.
            try script(realm,
                \\globalThis.events = [];
                \\globalThis.aborter = new AbortController();
                \\globalThis.reason = {name: 'abort reason'};
                \\globalThis.finishWrite = undefined;
                \\globalThis.pendingWrite = new Promise(resolve => { finishWrite = resolve; });
                \\globalThis.source = new ReadableStream({
                \\  start(c) { c.enqueue('first'); c.enqueue('second'); },
                \\  cancel(value) { events.push(value === reason ? 'cancel' : 'wrong reason'); }
                \\});
                \\globalThis.destination = new WritableStream({
                \\  write(value) { events.push(value); aborter.abort(reason); return pendingWrite; },
                \\  abort(value) { events.push(value === reason ? 'abort' : 'wrong reason'); }
                \\});
                \\globalThis.finished = false;
                \\globalThis.pipeError = undefined;
                \\source.pipeTo(destination, {signal: aborter.signal}).then(
                \\  () => { finished = true; }, error => { finished = true; pipeError = error; });
                \\'ready'
            , "ready");
            try engine.performMicrotaskCheckpoint(agent);
            try script(realm,
                \\JSON.stringify([events, finished])
            , "[[\"first\",\"cancel\"],false]");
            try script(realm, "finishWrite(); 'finishing'", "finishing");
            try engine.performMicrotaskCheckpoint(agent);
            try script(realm,
                \\JSON.stringify([events, finished, pipeError === reason, source.locked, destination.locked])
            , "[[\"first\",\"cancel\",\"abort\"],true,true,false,false]");
            return;
        }

        try script(realm,
            \\globalThis.events = [];
            \\globalThis.source = new ReadableStream({
            \\  start(c) { globalThis.controller = c; }
            \\}, {highWaterMark: 0});
            \\globalThis.destination = new WritableStream({
            \\  write(value) { xs1RecordWrite(); events.push(value.marker); },
            \\  close() { events.push('closed'); }
            \\});
            \\globalThis.finished = false;
            \\source.pipeTo(destination).then(() => { finished = true; });
            \\'ready'
        , "ready");
        try engine.performMicrotaskCheckpoint(agent);
        const controller_value = try engine.evaluateClassicScript(realm, .{ .utf8 = "controller" }, "xs1-pipe.js", null, .{ .report = report });
        defer controller_value.release();
        var call: ControllerCall = .{ .controller = engine.convertToPlatformObject(realm, controller_value.value) orelse return error.NoController };
        {
            const chunk = try engine.evaluateClassicScript(realm, .{ .utf8 = "({marker: 'chunk'})" }, "xs1-pipe.js", null, .{ .report = report });
            defer chunk.release();
            call.chunk = chunk.value;
            defer call.chunk = runtime.JSValue.jsUndefined;
            // A native producer uses the public controller interface. Unlike
            // evaluating a classic script, runInRealm ends no script turn.
            try engine.runInRealm(realm, ControllerCall.enqueue, &call);
            try call.result;
        }
        try testing.expectEqual(@as(usize, 0), writes);
        // No script or test handle now holds the chunk. Keep it until the
        // write runs, or release it if the realm ends before its checkpoint.
        engine.requestGarbageCollection(agent);
        try testing.expectEqual(@as(usize, 0), writes);
        if (drop_pending) return;
        try engine.runInRealm(realm, ControllerCall.close, &call);
        try call.result;
        try engine.performMicrotaskCheckpoint(agent);
        try testing.expectEqual(@as(usize, 1), writes);
        try script(realm,
            \\JSON.stringify([events, finished, source.locked, destination.locked])
        , "[[\"chunk\",\"closed\"],true,false,false]");
    }
};

test "pipeTo defers write and drains an already-read chunk before close" {
    var trial: Trial = .{};
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}

test "pipeTo drops a queued chunk when its realm ends before the write" {
    var trial: Trial = .{ .drop_pending = true };
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}

test "pipeTo follows engine reentrant abort timing before the first write settles" {
    var trial: Trial = .{ .reentrant_abort = true };
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}
