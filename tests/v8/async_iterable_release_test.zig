//! The async iterable binding (interface.zig asyncIteratorCallback) releases
//! the iterator the impl hands it, once the return value has it.
//!
//! `stream.values()` and `for await (... of stream)` reach the impl's
//! call_values, which gives the binding an owned Global of the new WebIDL
//! asynchronous iterator object. The binding set it as the call's return
//! value and kept it: a strong root, so the iterator - its state, its
//! weak-armed record (protocol_async_iterator.zig), its reader and its stream
//! - lived to the agent's end, one per `for await`. Found by instances B2's
//! measurement (agents_concurrent_engine_state_test.zig): the live weak
//! callback records grew by one per round, in every agent.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

const no_hooks: protocol.HostHooks = .{};

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const answer = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(answer);
    if (reports.count != 0) return error.ScriptThrew;
    try testing.expectEqualStrings(expected, answer);
}

/// The live weak callback records `source`, run `rounds` times in `realm`,
/// leaves behind once collected.
fn recordsLeftBy(agent: *protocol.Agent, realm: runtime.Context, source: []const u8, rounds: usize) !i64 {
    try expectEval(realm, source, "ok");
    for (0..8) |_| try protocol.performMicrotaskCheckpoint(agent);
    protocol.notifyMemoryPressure(agent, .critical);
    const before = ffi.v8_Debug_LiveWeakCallbackData();
    for (0..rounds) |_| {
        try expectEval(realm, source, "ok");
        for (0..4) |_| try protocol.performMicrotaskCheckpoint(agent);
    }
    protocol.notifyMemoryPressure(agent, .critical);
    protocol.notifyMemoryPressure(agent, .critical);
    return ffi.v8_Debug_LiveWeakCallbackData() - before;
}

test "an async iterator script drops is collected: values() and for await keep nothing per call" {
    try protocol.initializeEngine(.{});
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();
    var scope = runtime.BrowserScope.init(std.heap.page_allocator);
    defer scope.deinit();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://iterators.test",
        .browser_scope = &scope,
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(realm, .global_detached);

    const rounds = 100;
    // An iterator made and dropped at once.
    const values_left = try recordsLeftBy(agent, realm, "new ReadableStream({ start(c) { c.close(); } }).values(); 'ok'", rounds);
    // A for await to the end of the stream (its iterator from @@asyncIterator).
    const for_await_left = try recordsLeftBy(agent, realm,
        \\globalThis.total = 0;
        \\(async () => { for await (const chunk of new ReadableStream({ start(c) { c.enqueue(2); c.enqueue(3); c.close(); } })) total += chunk; })();
        \\'ok'
    , rounds);
    try expectEval(realm, "String(total)", "5");
    if (values_left >= rounds / 2 or for_await_left >= rounds / 2) {
        std.debug.print("weak callback records left: {d} by values(), {d} by for await, over {d} rounds each\n", .{ values_left, for_await_left, rounds });
        return error.IteratorsKept;
    }
}
