//! The wrapper redesign's P2 (tmp/redesign/wrapper-redesign-design.md
//! section 7, P2): a node's wrapper leaves the wrapper cache. It is a weak
//! `v8::Global<v8::Object>` constructed in place in the node's own slot
//! (engine.NodeWrapperSlot) - pre-Oilpan Blink's `ScriptWrappable::m_wrapper`
//! (Chromium 45 bindings/core/v8/ScriptWrappable.h) - whose weak parameter is
//! the node's 8-byte cell in its agent's registry. No CacheEntry, no map
//! slot, no `new Global` box, no WeakCallbackData and no entry in the
//! process-wide armed map.
//!
//! - The FIRST pass resets the slot in place (V8: "Handle not reset in first
//!   callback") and frees the cell; the agent's drain - at its safe point
//!   after the collection, unless a walk holds the agent's teardowns -
//!   releases the wrapper's
//!   counted reference. The adapter never frees a node: the counts decide.
//! - A node's pending-activity keep is the agent's (its keep table): the
//!   slot's Global is strong while one remains.
//!
//! The collections are V8's own (LowMemoryNotification through the FFI): the
//! finalizers of what one finds dead run when it returns; nothing drains
//! the deferred teardown queue (engine.requestGarbageCollection would).
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

    /// Whether `source` evaluates to true.
    fn holds(self: Page, source: []const u8) !bool {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return engine.toBoolean(self.realm, held.value);
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
/// count 1. Whatever making it queued is drained.
fn detachedDiv(page: Page) !struct { div: Watched, node: *NodeBase } {
    const div = try page.instance("globalThis.d = new Document(); globalThis.x = d.createElement('div'); x");
    const node = dom.instance_bridge.getNodeBase(div) orelse return error.NotANode;
    if (page.queue) |queue| queue.drainAll();
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(node));
    return .{ .div = Watched.of(div), .node = node };
}

/// The adapter's counter `name` now (engine.diagnosticCounters).
fn counter(name: []const u8) !i64 {
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    std.debug.print("the adapter reports no counter named {s}\n", .{name});
    return error.CounterMissing;
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

    fn wrap(page: Page, instance: *runtime.Instance) !void {
        var self: WrapAgain = .{ .realm = page.realm, .instance = instance };
        try engine.runInRealm(page.realm, steps, &self);
        try self.result;
    }
};

/// The binding's wrap of `instance` (template_registry.wrapInstanceAsV8Object),
/// with no script run: the wrapper is BORROWED, and nothing else holds it.
fn wrapDirect(page: Page, instance: *runtime.Instance) !void {
    const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(page.agent));
    const enter = v8.ffi.v8_Isolate_GetCurrent() != isolate;
    if (enter) v8.ffi.v8_Isolate_Enter(isolate);
    defer if (enter) v8.ffi.v8_Isolate_Exit(isolate);
    const context: *v8.ffi.Context = @ptrCast(@alignCast(page.realm.engine_ctx.?));
    _ = try v8.template_registry.wrapInstanceAsV8Object(instance, instance.vtable.name, isolate, context);
}

test "a node wrap adds no wrapper cache entry and no weak callback record: its wrapper is the agent's" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document(); globalThis.xs = [];");
    queue.drainAll();

    const entries = try counter("wrapper_cache_entries");
    const weak_records = try counter("live_weak_callback_data");
    const node_wrappers = try counter("node_wrappers");
    try page.run("for (let i = 0; i < 100; i++) xs.push(d.createElement('div')); xs.push(d.createTextNode('t'));");
    queue.drainAll();
    // 100 elements and a Text, made by factories: 101 node wrappers, every
    // one in its node's slot and its agent's registry.
    try testing.expectEqual(entries, try counter("wrapper_cache_entries"));
    try testing.expectEqual(weak_records, try counter("live_weak_callback_data"));
    try testing.expectEqual(node_wrappers + 101, try counter("node_wrappers"));
    // Identity: the wrapper the binding hands back again is the one script
    // has.
    try testing.expect(try page.holds("(() => { const f = d.createDocumentFragment(); f.appendChild(xs[0]); f.appendChild(xs[1]); return f.firstChild === xs[0] && xs[0].nextSibling === xs[1]; })()"));

    // Their collection empties the registry again.
    try page.run("globalThis.xs = null;");
    page.collect();
    try testing.expectEqual(node_wrappers, try counter("node_wrappers"));
}

test "the first collection that finds a node wrapper unreachable empties the slot; the drain releases the count" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);
    try testing.expect(!runtime.lifetime.slotOf(made.node).isEmpty());

    try page.run("globalThis.x = null;");
    page.collect();
    // Reset in the first pass; the second released the wrapper's reference,
    // which was the tree's last hold: queued, never freed by the collector.
    try testing.expect(made.div.alive());
    try testing.expect(runtime.lifetime.slotOf(made.node).isEmpty());
    try testing.expectEqual(@as(u32, 0), dom.refcount.count(made.node));
    try testing.expectEqual(@as(usize, 1), queue.len());
    queue.drainAll();
    try testing.expect(!made.div.alive());
}

test "an agent made without a deferred teardown queue: a holder's count keeps the node past its wrapper too" {
    // The SAFETY item's repro (lane wr1 batch 1): a test's own agent, no
    // queue. RED on main 7ef471b4648 - finalizeEntry's queue-less branch
    // freed the collected root whatever its count (generation moved, the
    // node read 0xdd). With P2 a node wrapper's collection only empties the
    // slot and releases the wrapper's reference: the adapter never frees a
    // node (tmp/redesign/wrapper-redesign-design.md 3.5, 7 P2).
    const page = try Page.open(null);
    defer page.close();
    const made = try detachedDiv(page);
    dom.refcount.holderRef(made.node);
    try page.run("globalThis.x = null;");
    page.collect();
    // Read nothing of the node before its slot says it is still there.
    try testing.expect(made.div.alive());
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(made.node));
    try testing.expect(runtime.lifetime.slotOf(made.node).isEmpty());
    // With no queue the counts free nothing: the realm's end does.
    dom.refcount.holderDeref(made.node);
    try testing.expect(made.div.alive());
}

test "while a walk holds the agent's teardowns the drain waits; a wrap in between is a second reference" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);
    try page.run("globalThis.x = null;");

    engine.deferTeardowns(page.realm);
    page.collect();
    // The first pass emptied the slot; the release waits for the hold's end.
    try testing.expect(runtime.lifetime.slotOf(made.node).isEmpty());
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(made.node));
    // The host hands the node to script again (the binding's wrap, made
    // here directly: a hold forbids running script): a new wrapper, its own
    // reference.
    try wrapDirect(page, made.div.instance);
    try testing.expect(!runtime.lifetime.slotOf(made.node).isEmpty());
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(made.node));
    engine.resumeTeardowns(page.realm);
    // The collected wrapper's release, and only that one.
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(made.node));
    try testing.expect(made.div.alive());
    try testing.expect(queue.isEmpty());

    // The new wrapper, unreached, goes the same way.
    page.collect();
    try testing.expect(runtime.lifetime.slotOf(made.node).isEmpty());
    try testing.expectEqual(@as(usize, 1), queue.len());
    queue.drainAll();
    try testing.expect(!made.div.alive());
}

test "a node's pending-activity keep holds its wrapper strongly; its release lets the collector take it" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);
    engine.keepPlatformObjectAlive(made.div.instance);
    try page.run("globalThis.x.expando = 7; globalThis.x = null;");
    page.collect();
    try testing.expect(!runtime.lifetime.slotOf(made.node).isEmpty());
    try testing.expect(engine.hasWrapper(made.div.instance));
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(made.node));
    // The same wrapper when script reaches it again: no new reference.
    try WrapAgain.wrap(page, made.div.instance);
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(made.node));

    engine.releasePlatformObject(made.div.instance);
    page.collect();
    try testing.expect(runtime.lifetime.slotOf(made.node).isEmpty());
    try testing.expect(!engine.hasWrapper(made.div.instance));
    try testing.expectEqual(@as(usize, 1), queue.len());
    queue.drainAll();
    try testing.expect(!made.div.alive());
}

test "a pending-activity keep taken before the wrap holds the wrapper the binding makes later" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document(); globalThis.p = d.createElement('p'); p.innerHTML = '<span></span>';");
    queue.drainAll();
    const p = try page.instance("p");
    const span_node = dom.instance_bridge.getNodeBase(p).?.first_child.?;
    const span: *runtime.Instance = @ptrCast(@alignCast(span_node.ownerInstance().?));
    try testing.expect(runtime.lifetime.slotOf(span_node).isEmpty());
    engine.keepPlatformObjectAlive(span);
    try page.run("p.firstChild.expando = 3;");
    try page.run("globalThis.p = null;");
    page.collect();
    // The span's keep holds its wrapper, and its wrapper its tree's.
    try testing.expect(!runtime.lifetime.slotOf(span_node).isEmpty());
    engine.releasePlatformObject(span);
    page.collect();
    try testing.expect(runtime.lifetime.slotOf(span_node).isEmpty());
}

test "a node torn down under its live wrapper: the wrapper is severed and its slot emptied, its reference released" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);
    const before = try counter("node_wrappers");
    // A teardown the counts did not decide - a forced realm end's
    // coordinated teardown frees a tree whatever its counts say (refcount
    // 7a's net) - reached here through the root's own teardown.
    dom.node_creation.destroyRoot(made.div.instance);
    try testing.expect(!made.div.alive());
    try testing.expectEqual(before - 1, try counter("node_wrappers"));
    // Script still holds the wrapper: it reaches no node through it - a
    // TypeError at the binding's unwrap, never the freed node.
    try testing.expect(try page.holds("(() => { try { globalThis.x.localName; return false; } catch (e) { return e instanceof TypeError; } })()"));
    try page.run("globalThis.x = null;");
    page.collect();
    queue.drainAll();
}

test "releaseNodeWrappers: every node wrapper ends and lets its reference go; the host's drain frees what only wrappers held" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const made = try detachedDiv(page);
    // One kept as well: its keep goes with the agent's end too.
    const kept = try page.instance("globalThis.k = d.createElement('span'); k");
    const kept_watched = Watched.of(kept);
    engine.keepPlatformObjectAlive(kept);
    queue.drainAll();
    try testing.expect(try counter("node_wrappers") >= 3);

    engine.releaseNodeWrappers(page.agent);
    try testing.expectEqual(@as(i64, 0), try counter("node_wrappers"));
    try testing.expect(runtime.lifetime.slotOf(made.node).isEmpty());
    try testing.expect(!engine.hasWrapper(kept));
    try testing.expect(made.div.alive());
    try testing.expectEqual(@as(u32, 0), dom.refcount.count(made.node));
    // Idempotent.
    engine.releaseNodeWrappers(page.agent);
    try testing.expectEqual(@as(i64, 0), try counter("node_wrappers"));
    // The host's last drain: the trees only wrappers held go.
    try testing.expect(!queue.isEmpty());
    queue.drainAll();
    try testing.expect(!made.div.alive());
    try testing.expect(!kept_watched.alive());
}
