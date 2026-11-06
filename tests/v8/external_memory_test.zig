//! [external_memory] (engine.AgentOptions.external_memory): the V8 adapter
//! tells its isolate how the host's native memory - a Browser's DOM,
//! runtime.gc.ExternalMemory - moved, at the binding exit back into script
//! that brings the DOM-algorithm depth to zero and at each microtask
//! checkpoint, once it moved report_step (128 KB, V8's own re-check step);
//! the agent's end takes back what it reported (external_memory.zig).
//!
//! Each test makes its own agent and its own figure, moved by hand: what the
//! adapter reads is the figure, whoever moves it (dom.instance_bridge does,
//! in a Browser - tests/html/perf1_external_memory_test.zig).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const DeferredTeardown = runtime.gc.DeferredTeardown;
const ExternalMemory = runtime.gc.ExternalMemory;

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

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,
    realm_open: bool = true,

    fn open(queue: *DeferredTeardown, memory: *ExternalMemory) !Page {
        test_process.start();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &no_hooks,
            .host = null,
            .deferred_teardown = queue,
            .external_memory = memory,
        });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: *Page) void {
        if (self.realm_open) protocol.destroyWindowRealm(self.realm, .global_detached);
        self.realm_open = false;
        protocol.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *v8.ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    /// A script that calls a binding (a Document constructed once, then its
    /// nodeType attribute) and returns into script: the outermost binding exit.
    fn callBinding(self: Page) !void {
        try self.run("void (globalThis.doc ??= new Document()).nodeType;");
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    /// V8's own count of the isolate's external memory: what it collects by
    /// (backing stores and the host's reports).
    fn external(self: Page) usize {
        return v8.ffi.v8_Isolate_GetExternalMemory(self.isolate());
    }

    fn reported(self: Page) usize {
        return v8.external_memory.reportedOn(self.isolate());
    }
};

test "a binding exit tells V8 how the host's memory grew and shrank, once it moved 128 KB" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    var page = try Page.open(&queue, &memory);
    defer page.close();

    const start = page.external();
    try testing.expectEqual(@as(usize, 0), page.reported());

    // 10 MB of DOM: the next binding exit reports it, and V8 counts it.
    memory.add(10 << 20);
    try page.callBinding();
    try testing.expectEqual(memory.live, page.reported());
    try testing.expectEqual(start + memory.live, page.external());

    // Under report_step: no call to V8.
    memory.add(ExternalMemory.report_step / 2);
    try page.callBinding();
    try testing.expectEqual(@as(usize, 10 << 20), page.reported());

    // Freed: V8's count goes back DOWN, as far as the figure went.
    memory.sub(8 << 20);
    try page.callBinding();
    try testing.expectEqual(memory.live, page.reported());
    try testing.expectEqual(start + memory.live, page.external());
}

test "a microtask checkpoint outside a DOM algorithm reports too" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    var page = try Page.open(&queue, &memory);
    defer page.close();

    const start = page.external();
    memory.add(4 << 20);
    try protocol.performMicrotaskCheckpoint(page.agent);
    try testing.expectEqual(memory.live, page.reported());
    try testing.expectEqual(start + memory.live, page.external());

    // Inside a DOM algorithm the checkpoint leaves it to the binding exit.
    memory.add(4 << 20);
    queue.enterAlgorithm();
    try protocol.performMicrotaskCheckpoint(page.agent);
    try testing.expectEqual(@as(usize, 4 << 20), page.reported());
    queue.leaveAlgorithmToNative();
    try protocol.performMicrotaskCheckpoint(page.agent);
    try testing.expectEqual(memory.live, page.reported());
}

test "the agent's end takes back what it reported, and releases the figure" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    var page = try Page.open(&queue, &memory);
    defer page.close();

    const start = page.external();
    memory.add(32 << 20);
    try page.callBinding();
    try testing.expectEqual(start + memory.live, page.external());

    // The agent's end's step, alone: V8's count is where it started.
    {
        const entered = v8.ffi.v8_Isolate_GetCurrent() != page.isolate();
        if (entered) v8.ffi.v8_Isolate_Enter(page.isolate());
        defer if (entered) v8.ffi.v8_Isolate_Exit(page.isolate());
        v8.external_memory.uninstall(page.isolate());
    }
    try testing.expectEqual(start, page.external());
    try testing.expectEqual(@as(usize, 0), page.reported());
    // Not the agent's any more: the figure moves without a report.
    memory.add(1 << 20);
    try page.callBinding();
    try testing.expectEqual(start, page.external());
}

// 600 detached divs, made one script each and dropped, each standing for
// 1 MB of native memory the way a node's wrapper stands for its tree: told
// about it, V8 collects - nothing forces a collection - and each dropped
// div's wrapper dies, its deref queueing the div as a garbage tree (refcount
// step 7). Without the report V8's heap barely grows (600 small wrappers),
// it never collects, and every div waits with its wrapper.
test "reported memory makes V8 collect dropped wrappers with no forced collection" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    var memory: ExternalMemory = .{};
    var page = try Page.open(&queue, &memory);
    defer page.close();

    try page.run("globalThis.doc = new Document();");
    const queued_before = queue.queued_total;
    var i: usize = 0;
    while (i < 600) : (i += 1) {
        // The host's DOM grows with each node; the script's binding exit
        // reports it.
        memory.add(1 << 20);
        try page.run("void doc.createElement('div');");
    }
    const queued = queue.queued_total - queued_before;
    if (queued < 300) std.debug.print("600 dropped wrappers beside 600 MB reported: {d} queued by their collection\n", .{queued});
    try testing.expect(queued >= 300);
}
