//! A node a native holder counts outlives its wrapper: the counts decide
//! every free of a node during its realm's life (refcount step 7, lane
//! refcount9's 7a: tmp/plans/refcount9-design.md B2), so the collection that
//! takes the node's last wrapper releases the wrapper's reference and frees
//! nothing while a holder's reference remains - WebKit's JSDOMWrapper drops
//! only its own `Ref` (m_wrapped), and the node lives on its holder's
//! (Source/WebCore/bindings/js/JSDOMWrapper.h). The holder's release then
//! makes the tree garbage, and the agent's queue frees it in a slice.
//!
//! The wrapper redesign's SAFETY item (lane wr1 batch 2; feature-queue
//! "SAFETY (lifetime)"): a node held by `dom.refcount.holderRef` alone read
//! back freed (generation 3 -> 0, 0xdd) after its wrapper's collection - in an
//! agent made WITHOUT a deferred teardown queue, where the second pass kept
//! the pre-step-7 model (wrapper_cache.finalizeEntry: "An agent made without a
//! queue ... keeps the old model below: the second pass frees a collected root
//! nothing owns") and freed it whatever its count. Every production agent has
//! a queue (Browser.zig and worker_host.zig pass AgentOptions.deferred_teardown).
//!
//! The collections are V8's own (LowMemoryNotification through the FFI), as
//! in deferred_teardown_test.zig: engine.requestGarbageCollection also drains
//! the queue by contract.
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

const DeferredTeardown = runtime.gc.DeferredTeardown;
const SlabAllocator = runtime.SlabAllocator;
const NodeBase = dom.NodeBase;

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
    queue: ?*DeferredTeardown,

    /// An agent with `queue` as its deferred teardown queue (null: none, a
    /// test's own agent), and one window realm, made without the snapshot.
    fn open(queue: ?*DeferredTeardown) !Page {
        test_process.start();
        const no_hooks: engine.HostHooks = .{};
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &no_hooks,
            .host = null,
            .deferred_teardown = queue,
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
        return .{ .agent = agent, .realm = realm, .queue = queue };
    }

    fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
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

    /// V8's own full collection, twice: the finalizers of what each finds dead
    /// run when it returns; nothing drains the deferred teardown queue.
    fn collect(self: Page) void {
        const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(self.agent));
        v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
        v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
    }
};

/// A slab slot and the generation it had: whether the object is still there.
/// Read before anything of the node is: a freed node's fields are poison.
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

/// A detached <div> of a Document script keeps (`globalThis.d`), wrapped
/// once (`globalThis.x`), the creator's reference adopted by that wrapper:
/// count 1. Whatever making it queued (nothing: no fragment) is drained.
fn detachedDiv(page: Page) !struct { div: Watched, node: *NodeBase } {
    const div = try page.instance("globalThis.d = new Document(); globalThis.x = d.createElement('div'); x");
    const node = dom.instance_bridge.getNodeBase(div) orelse return error.NotANode;
    if (page.queue) |queue| queue.drainAll();
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(node));
    return .{ .div = Watched.of(div), .node = node };
}

test "a node a holder counts survives its wrapper's collection, and goes when the holder lets it go" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);

    // The holder's reference (a parser structure's, an event path's, an
    // inner-text walk's parent): the node's count is its wrapper's and this.
    dom.refcount.holderRef(made.node);
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(made.node));

    try page.run("globalThis.x = null;");
    page.collect();
    try testing.expect(made.div.alive());
    // The wrapper's reference went with it; the node is unwrapped now and
    // held by the holder alone.
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(made.node));
    try testing.expect(runtime.lifetime.slotOf(made.node).isEmpty());
    try testing.expect(!made.node.rc_flags.garbage);
    try testing.expect(queue.isEmpty());

    // A requested collection drains the queue: still nothing to free.
    engine.requestGarbageCollection(page.agent);
    try testing.expect(made.div.alive());
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(made.node));

    // The holder's release leaves the tree with no hold: it is queued, and
    // its slice frees it.
    dom.refcount.holderDeref(made.node);
    try testing.expectEqual(@as(usize, 1), queue.len());
    try testing.expect(made.div.alive());
    queue.drainAll();
    try testing.expect(!made.div.alive());
}

test "a node a CountedRef holds survives its wrapper's collection; the release frees it" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);

    // node_holds' counted reference: what most production holders keep (an
    // event's path, a custom element reaction, a script element's fetch).
    var held: dom.node_holds.CountedRef = .{};
    held.take(made.div.instance, made.node);
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(made.node));

    try page.run("globalThis.x = null;");
    page.collect();
    try testing.expect(made.div.alive());
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(made.node));
    try testing.expect(queue.isEmpty());

    held.release(made.div.instance);
    try testing.expectEqual(@as(usize, 1), queue.len());
    queue.drainAll();
    try testing.expect(!made.div.alive());
}

test "a node a holder counts is wrapped again after its wrapper's collection: the new wrapper is a second reference" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);
    dom.refcount.holderRef(made.node);
    try page.run("globalThis.x.expando = 1; globalThis.x = null;");
    page.collect();
    try testing.expect(made.div.alive());
    try testing.expect(runtime.lifetime.slotOf(made.node).isEmpty());

    // Script reaches the node again through what the host holds (the
    // binding wraps it as it returns it): a fresh wrapper, its own reference.
    var wrap: WrapAgain = .{ .realm = page.realm, .instance = made.div.instance };
    try engine.runInRealm(page.realm, WrapAgain.steps, &wrap);
    try wrap.result;
    try testing.expect(!runtime.lifetime.slotOf(made.node).isEmpty());
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(made.node));
    dom.refcount.holderDeref(made.node);
    try testing.expect(queue.isEmpty());
    try testing.expect(made.div.alive());
}

/// The binding's wrap of `instance` in `realm`: a sequence of it, as an
/// operation returning it would make (the array is let go at once; the
/// wrapper lives until a collection takes it).
const WrapAgain = struct {
    realm: runtime.Context,
    instance: *runtime.Instance,
    result: anyerror!void = {},

    fn steps(data: ?*anyopaque) void {
        const self: *WrapAgain = @ptrCast(@alignCast(data.?));
        const array = engine.createSequenceOfPlatformObjects(self.realm, &.{self.instance}) catch |err| {
            self.result = err;
            return;
        };
        array.release();
    }
};
