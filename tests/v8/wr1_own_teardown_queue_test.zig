//! An agent made without a deferred teardown queue (AgentOptions.
//! deferred_teardown null: only a test's own agent) gets the adapter's own
//! (lane wr1 batch 2; the integrator's decision (A), 2026-11-09 02:42 UTC).
//!
//! The wrapper redesign's P2 made the adapter free no node: a node wrapper's
//! collection only lets the wrapper's reference go, and a tree the counts
//! leave with no hold is freed through its agent's queue
//! (dom.refcount_teardown.settle). Before P2 a queue-less agent's garbage was
//! freed count-blind - wrapper_cache.finalizeEntry's queue-less second pass,
//! and its realm's end - and both paths no longer see nodes; so every agent
//! needs a queue, and the adapter makes one when the host gives none. It
//! drains as the host's would - at a requested collection, at each realm's
//! end, at the agent's end - and goes with the agent, before its isolate is
//! disposed and its C++ heap freed. No event loop slices it.
//!
//! The agents here allocate their own state with std.testing.allocator, so
//! the queue's storage is leak-checked; the Crane test runner checks
//! `runtime.standalone_objects` after each test, so a tree left unfreed fails.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent per test.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const SlabAllocator = runtime.SlabAllocator;

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

/// A queue-less agent (its own state on std.testing.allocator) and one
/// window realm, made without the snapshot.
const Page = struct {
    agent: *engine.Agent,
    realm: runtime.Context,
    realm_open: bool = true,

    fn open() !Page {
        test_process.start();
        const no_hooks: engine.HostHooks = .{};
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &no_hooks,
            .host = null,
            .allocator = testing.allocator,
        });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn endRealm(self: *Page) void {
        if (!self.realm_open) return;
        engine.destroyWindowRealm(self.realm, .global_detached);
        self.realm_open = false;
    }

    fn close(self: *Page) void {
        self.endRealm();
        engine.destroyAgent(self.agent);
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return engine.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    /// V8's own full collection, twice; drains nothing.
    fn collect(self: Page) void {
        const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(self.agent));
        v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
        v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
    }
};

const Watched = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) Watched {
        return .{ .instance = instance, .generation = SlabAllocator.generationOf(instance) };
    }

    fn alive(self: Watched) bool {
        return SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

test "a queue-less agent answers a queue of its own" {
    var page = try Page.open();
    defer page.close();
    try testing.expect(engine.deferredTeardownOf(page.agent) != null);
}

test "a queue-less agent's garbage tree is freed at a requested collection" {
    var page = try Page.open();
    defer page.close();
    // A detached tree script made and dropped, its document too.
    const div = Watched.of(try page.instance("globalThis.d = new Document(); globalThis.x = d.createElement('div'); x.innerHTML = '<span>a</span><span>b</span>'; x"));
    const span: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getNodeBase(div.instance).?.first_child.?.ownerInstance().?));
    const first_span = Watched.of(span);
    const document = Watched.of(try page.instance("d"));
    try page.run("globalThis.x = null; globalThis.d = null;");
    engine.requestGarbageCollection(page.agent);
    engine.requestGarbageCollection(page.agent);
    try testing.expect(!div.alive());
    try testing.expect(!first_span.alive());
    try testing.expect(!document.alive());
}

test "a queue-less agent's end frees what only its node wrappers held, before its isolate goes" {
    var page = try Page.open();
    // Held by script to the end: the realm's end lets no node wrapper go
    // (P2), so the agent's end does (engine.releaseNodeWrappers), which
    // queues the trees - and drains its own queue before the isolate is
    // disposed and its C++ heap freed (protocol_agents.endAgent).
    const div = Watched.of(try page.instance("globalThis.d = new Document(); globalThis.x = d.createElement('div'); x.appendChild(d.createElement('b')); x"));
    const document = Watched.of(try page.instance("d"));
    if (engine.deferredTeardownOf(page.agent)) |queue| try testing.expect(queue.isEmpty());
    page.close();
    try testing.expect(!div.alive());
    try testing.expect(!document.alive());
}

test "a queue-less agent's realm end frees the garbage its trees left" {
    var page = try Page.open();
    defer page.close();
    const div = Watched.of(try page.instance("globalThis.d = new Document(); globalThis.x = d.createElement('div'); x"));
    const node = dom.instance_bridge.getNodeBase(div.instance).?;
    dom.refcount.holderRef(node);
    try page.run("globalThis.x = null;");
    page.collect();
    dom.refcount.holderDeref(node);
    try testing.expect(div.alive());
    page.endRealm();
    try testing.expect(!div.alive());
}
