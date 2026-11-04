//! Counting the global handles a script keeps, per round, in an agent of the
//! test's own: V8's used global handle bytes for the agent's isolate - every
//! Global of the agent, whoever made it, and nothing of any other Browser of
//! the process (docs/testing/test-variant-findings-2026-11-02.tsv M2) - read
//! after two critical memory-pressure collections, over one handle's bytes.
//! Shared by the tests that pin what a script, a stream or an iterator keeps
//! (async_iterable_release_test.zig, streams_settled_promise_handles_test.zig).

const std = @import("std");
const test_process = @import("test_process.zig");
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

/// Evaluate `source` in `realm` as a classic script; its completion value,
/// as a string, must be `expected`, and it must report nothing.
pub fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const answer = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(answer);
    if (reports.count != 0) return error.ScriptThrew;
    try testing.expectEqualStrings(expected, answer);
}

/// An agent of the test's own and a Window realm in it. `end` ends both.
pub const Page = struct {
    scope: runtime.BrowserScope,
    agent: *protocol.Agent,
    realm: runtime.Context,

    pub fn start(self: *Page, origin: []const u8) !void {
        test_process.start();
        interfaces.process_hooks.startHooksForTest();
        self.scope = runtime.BrowserScope.init(std.heap.page_allocator);
        errdefer self.scope.deinit();
        self.agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(self.agent);
        self.realm = try self.newRealm(origin);
    }

    /// Another Window realm in the page's agent. OWNED: destroyWindowRealm.
    pub fn newRealm(self: *Page, origin: []const u8) !runtime.Context {
        return protocol.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = origin,
            .browser_scope = &self.scope,
            .create_global_object = WindowHost.createGlobalObject,
        });
    }

    pub fn isolate(self: *const Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    pub fn end(self: *Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
        self.scope.deinit();
    }
};

/// The global handles `source` - a script whose completion value is 'ok' -
/// run `rounds` times in `realm`, leaves behind once collected; each round
/// is followed by four microtask checkpoints.
pub fn handlesLeftBy(agent: *protocol.Agent, realm: runtime.Context, source: []const u8, rounds: usize) !i64 {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    try expectEval(realm, source, "ok");
    for (0..8) |_| try protocol.performMicrotaskCheckpoint(agent);
    protocol.notifyMemoryPressure(agent, .critical);
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    for (0..rounds) |_| {
        try expectEval(realm, source, "ok");
        for (0..4) |_| try protocol.performMicrotaskCheckpoint(agent);
    }
    protocol.notifyMemoryPressure(agent, .critical);
    protocol.notifyMemoryPressure(agent, .critical);
    const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    return @divTrunc(after - before, try handleBytes(realm, isolate));
}

/// `handlesLeftBy` per round, rounded to the nearest handle.
pub fn handlesPerRound(agent: *protocol.Agent, realm: runtime.Context, source: []const u8, rounds: usize) !i64 {
    const left = try handlesLeftBy(agent, realm, source, rounds);
    const n: i64 = @intCast(rounds);
    return @divFloor(left * 2 + n, n * 2);
}

/// One global handle's bytes in `isolate`: a value of `realm` held beside
/// another (the first evaluation's own one-time handles made by then), then
/// let go.
pub fn handleBytes(realm: runtime.Context, isolate: *ffi.Isolate) !i64 {
    var reports: Reports = .{};
    const first = try protocol.evaluateClassicScript(realm, .{ .utf8 = "({})" }, "", null, reports.reporter());
    defer first.release();
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const held = try protocol.evaluateClassicScript(realm, .{ .utf8 = "({})" }, "", null, reports.reporter());
    const holding = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    held.release();
    try testing.expect(holding > before);
    return @intCast(holding - before);
}
