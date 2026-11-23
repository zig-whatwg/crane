//! engine.TracedHold on V8 (refcount step 8, the trace-time design approved
//! by the integrator 2026-11-23 6:53 PM ET): an owner's hold of a value it
//! keeps for script, traced at collection time from its owner - Blink's
//! TraceWrapperV8Reference. Pins the two halves of its contract:
//! - NO ROOT in a full collection: a hold nothing traces is cleared, and then
//!   reads empty (undefined), as a listener nobody's wrapper reaches is gone;
//! - a ROOT in a young-generation one: a scavenge never takes a held value,
//!   so a listener survives scavenges whatever its target's wrapper does.
//! And the value it reads is the value it was given, through the readers the
//! protocol uses on it (retainValue, sameValue).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const interfaces = @import("interfaces");

const DeferredTeardown = runtime.gc.DeferredTeardown;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) engine.Reporter {
        return .{ .report = report, .host = self };
    }
};

const Page = struct {
    agent: *engine.Agent,
    realm: runtime.Context,
    queue: *DeferredTeardown,

    fn open(queue: *DeferredTeardown) !Page {
        test_process.start();
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &test_process.no_hooks,
            .host = null,
            .deferred_teardown = queue,
        });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm, .queue = queue };
    }

    fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    /// `source`'s completion, OWNED.
    fn evaluate(self: Page, source: []const u8) !engine.Owned {
        var reports: Reports = .{};
        const value = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        try testing.expectEqual(@as(usize, 0), reports.count);
        return value;
    }

    /// A traced hold of a fresh function nothing else keeps: the
    /// evaluation's own hold goes once the traced one is made.
    fn heldFunction(self: Page) !engine.TracedCallback {
        const function = try self.evaluate("(() => { const big = new Array(64).fill(7); return () => big.length; })()");
        defer function.release();
        return (engine.BorrowedCallbackFunction{ .function = function.value }).keepTraced();
    }

    fn enter(self: Page) bool {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        return entered;
    }

    fn leave(self: Page, entered: bool) void {
        if (entered) ffi.v8_Isolate_Exit(self.isolate());
    }

    fn fullGC(self: Page) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        self.queue.drainAll();
    }

    fn minorGC(self: Page, n: u32) !void {
        const entered = self.enter();
        defer self.leave(entered);
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), n);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) >= before + n);
        while (ffi.v8_Platform_PumpMessageLoop(self.isolate())) {}
        self.queue.drainAll();
    }
};

test "a traced hold reads the value it was given, through the readers the protocol uses on it" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const function = try page.evaluate("globalThis.kept = () => 42; kept");
    defer function.release();
    const held = (engine.BorrowedCallbackFunction{ .function = function.value }).keepTraced();
    defer held.release();
    try testing.expect(!held.hold.isEmpty());
    try testing.expect(engine.sameValue(page.realm, held.hold.value(), function.value));
    const retained = try engine.retainValue(page.realm, held.hold.value());
    defer retained.release();
    try testing.expect(engine.sameValue(page.realm, retained.value, function.value));
}

test "a traced hold nobody traces is cleared by a full collection, and reads empty" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const held = try page.heldFunction();
    defer held.release();
    try testing.expect(!held.hold.isEmpty());
    page.fullGC();
    try testing.expect(held.hold.isEmpty());
    try testing.expect(held.hold.value().isUndefined());
}

test "a held value survives scavenges: a traced hold is a root in a young-generation collection" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const held = try page.heldFunction();
    defer held.release();
    try page.minorGC(4);
    try testing.expect(!held.hold.isEmpty());
    // Still the function: it runs.
    const retained = try engine.retainValue(page.realm, held.hold.value());
    defer retained.release();
    try testing.expect(retained.value == .handle);
}
