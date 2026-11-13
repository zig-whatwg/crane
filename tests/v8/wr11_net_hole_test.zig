//! Refcount step 7a's ended-realm net, and the hole in it (lane wr1 batch 11,
//! R3; tmp/plans/feature-queue.md "THE 7a NET'S HOLE", lane v8up b7).
//!
//! The net (node_wrappers.zig `endedRealmNet`, `endRealm`): a detached tree of
//! a realm that ENDED, still held by its own pending work's counted reference
//! - an <img>'s image update, a dialog's close watcher: work only the realm's
//! end would have let go - is freed whatever its counts once no wrapper
//! reaches it. A holder that counted a node there forgets it (its generation
//! net: dom.node_holds.CountedRef.release).
//!
//! The net looked at such a tree at two moments only: when a wrapper's
//! release ran (`endedRealmNet`), and at the realm's end for the releases
//! still waiting for the drain (`endRealm`). A tree whose last wrapper was
//! released while its realm was ALIVE met neither: the first look declined
//! (the realm lives: its pending work may still end by itself), and nothing
//! looked again at the realm's end. It stayed to the agent's end. WHEN a
//! collection's releases run decided which case a tree fell in - which is why
//! node wrappers' releases kept V8's second-pass timing while every other
//! finalizer moved to the first pass (v8_wrapper.cpp
//! `noteNodeWrappersCollected`), at a cost of 19 MB on dom.clone-node.
//!
//! What these pin:
//! 1. the hole: released while the realm lives, then the realm ends - the
//!    tree is freed at that end (a root, and a tree held through a child);
//! 2. the order the net always handled: the wrapper outlives the realm;
//! 3. the net never frees a tree a wrapper still reaches, at either look:
//!    since the redesign's P7 a wrapped node wraps no ancestor, so the ROOT's
//!    empty slot does not answer for its tree (dom.wrapper_tracing
//!    .holdsWrapper does);
//! 4. a wrapper released inside a shadow tree answers for its HOST's tree
//!    (the host-including tree is what the counts and the walk keep);
//! 5. the remembered roots are bounded by the trees that still wait.
//!
//! Each test has its own agent with two Window realms: `page`, which keeps
//! the agent alive, and a frame that ends inside the test. The collections
//! are V8's own, through the FFI: `collect` (full) runs the agent's safe
//! point when it returns (the releases are drained); `scavengeHolding`
//! (young generation) does not (they stay recorded until `safePoint`). The
//! file shares tests/v8's process.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const ffi = v8.ffi;
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

/// One agent, its deferred teardown queue, and the Window realm that keeps
/// it alive while a test's frames end.
const Fixture = struct {
    agent: *engine.Agent,
    page: runtime.Context,
    queue: *DeferredTeardown,

    fn open(queue: *DeferredTeardown) !Fixture {
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
        const page = try windowRealm(agent);
        return .{ .agent = agent, .page = page, .queue = queue };
    }

    fn close(self: Fixture) void {
        engine.destroyWindowRealm(self.page, .global_detached);
        engine.destroyAgent(self.agent);
    }

    fn windowRealm(agent: *engine.Agent) !runtime.Context {
        return engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
    }

    /// Another Window realm of the agent: the one a test ends.
    fn frame(self: Fixture) !runtime.Context {
        return windowRealm(self.agent);
    }

    fn isolate(self: Fixture) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    /// A full collection, twice, each followed by the agent's safe point:
    /// the releases of the wrappers it found dead have run when it returns.
    /// Nothing drains the deferred teardown queue.
    fn collect(self: Fixture) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
    }

    /// One young-generation collection with NO safe point after it: it drops
    /// the wrappers script let go of and could not tell from fresh ones (the
    /// redesign's P8) - whatever else of their tree is wrapped, which a full
    /// collection's walk would keep them for - and their releases stay
    /// recorded, as when V8 collects in the middle of a DOM algorithm, before
    /// the binding that runs it returns.
    fn scavengeHolding(self: Fixture) !void {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        defer if (entered) ffi.v8_Isolate_Exit(self.isolate());
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), 1);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) > before);
    }

    /// The agent's safe point: the recorded releases run.
    fn safePoint(self: Fixture) void {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        defer if (entered) ffi.v8_Isolate_Exit(self.isolate());
        _ = ffi.v8_Isolate_RunQueuedFinalizers(self.isolate());
    }
};

fn run(realm: runtime.Context, source: []const u8) !void {
    var reports: Reports = .{};
    const held = try engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, reports.reporter());
    held.release();
    try testing.expectEqual(@as(usize, 0), reports.count);
}

/// The platform object `source` evaluates to, no wrapper of it kept.
fn instanceOf(realm: runtime.Context, source: []const u8) !*runtime.Instance {
    var reports: Reports = .{};
    const held = try engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, reports.reporter());
    defer held.release();
    try testing.expectEqual(@as(usize, 0), reports.count);
    return engine.convertToPlatformObject(realm, held.value) orelse error.NotAPlatformObject;
}

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

const Made = struct {
    watched: Watched,
    node: *NodeBase,
};

/// The node `source` evaluates to in `realm`, watched.
fn nodeOf(realm: runtime.Context, source: []const u8) !Made {
    const instance = try instanceOf(realm, source);
    const node = dom.instance_bridge.getNodeBase(instance) orelse return error.NotANode;
    return .{ .watched = Watched.of(instance), .node = node };
}

/// The binding's wrap of `instance` in `realm` (an operation returning it):
/// the wrapper lives until a collection takes it, and nothing holds it.
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

    fn wrap(realm: runtime.Context, instance: *runtime.Instance) !void {
        var self: WrapAgain = .{ .realm = realm, .instance = instance };
        try engine.runInRealm(realm, steps, &self);
        try self.result;
    }
};

/// The adapter's counter `name` now (engine.diagnosticCounters), read with
/// the fixture's isolate entered.
fn counterOf(fx: Fixture, name: []const u8) !i64 {
    const entered = ffi.v8_Isolate_GetCurrent() != fx.isolate();
    if (entered) ffi.v8_Isolate_Enter(fx.isolate());
    defer if (entered) ffi.v8_Isolate_Exit(fx.isolate());
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    std.debug.print("the adapter reports no counter named {s}\n", .{name});
    return error.CounterMissing;
}

test "the hole: a detached root its realm's pending work holds, whose wrapper was released while the realm lived, is freed at that realm's end" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);

    const div = try nodeOf(frame, "globalThis.d = new Document(); globalThis.x = d.createElement('div'); x");
    queue.drainAll();
    // The realm's pending work: an image update's hold on its element, a
    // close watcher's on its dialog - a counted reference that ends by
    // itself only if the work does.
    var pending: dom.node_holds.CountedRef = .{};
    pending.take(div.watched.instance, div.node);
    defer pending.release(div.watched.instance);
    defer queue.drainAll();
    try testing.expectEqual(@as(u32, 2), dom.refcount.count(div.node));

    // Script lets the wrapper go, a collection finds it dead, and its
    // release runs at the agent's safe point - with the realm alive.
    try run(frame, "globalThis.x = null;");
    fx.collect();
    try testing.expect(div.watched.alive());
    try testing.expect(runtime.lifetime.slotOf(div.node).isEmpty());
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(div.node));
    try testing.expect(queue.isEmpty());

    // The realm ends: no script of it runs again and its pending work never
    // ends by itself. The net frees the tree.
    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    queue.drainAll();
    try testing.expect(!div.watched.alive());
    // The work's own end, later, finds its element gone and lets nothing go
    // twice (`pending.release` above: an underflow would be an error log).
}

test "the hole: a detached tree held through a child - the root never held - is freed at its realm's end" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);

    // A detached <div> with an <img> in it; script keeps the img only.
    const img = try nodeOf(frame, "globalThis.d = new Document(); globalThis.x = d.createElement('div').appendChild(d.createElement('img')); x");
    const root = try nodeOf(frame, "x.parentNode");
    queue.drainAll();
    var pending: dom.node_holds.CountedRef = .{};
    pending.take(img.watched.instance, img.node);
    defer pending.release(img.watched.instance);
    defer queue.drainAll();

    try run(frame, "globalThis.x = null;");
    fx.collect();
    // Both wrappers went; the update's hold on the img keeps the tree.
    try testing.expect(root.watched.alive());
    try testing.expect(img.watched.alive());
    try testing.expect(runtime.lifetime.slotOf(root.node).isEmpty());
    try testing.expect(runtime.lifetime.slotOf(img.node).isEmpty());
    try testing.expect(queue.isEmpty());

    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    queue.drainAll();
    try testing.expect(!img.watched.alive());
    try testing.expect(!root.watched.alive());
}

test "the order the net always handled: the wrapper outlives its realm, and its release frees the tree the realm's pending work holds" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);

    const div = try nodeOf(frame, "globalThis.d = new Document(); globalThis.x = d.createElement('div'); x");
    queue.drainAll();
    var pending: dom.node_holds.CountedRef = .{};
    pending.take(div.watched.instance, div.node);
    defer pending.release(div.watched.instance);
    defer queue.drainAll();

    // The realm ends with the wrapper still there (its global held it).
    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    // The collections after it take the wrapper; its release meets a tree of
    // an ended realm that only that realm's work holds: freed, in a slice.
    var turns: usize = 0;
    while (turns < 6 and div.watched.alive()) : (turns += 1) {
        fx.collect();
        queue.drainAll();
    }
    try testing.expect(!div.watched.alive());
}

test "a tree the net declined is not freed at its realm's end while a wrapper reaches it again; that wrapper's release frees it" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);

    const span = try nodeOf(frame, "globalThis.d = new Document(); globalThis.x = d.createElement('div').appendChild(d.createElement('span')); x");
    const root = try nodeOf(frame, "x.parentNode");
    queue.drainAll();
    var pending: dom.node_holds.CountedRef = .{};
    pending.take(span.watched.instance, span.node);
    defer pending.release(span.watched.instance);
    defer queue.drainAll();

    // Declined: both wrappers released while the realm lives.
    try run(frame, "globalThis.x = null;");
    fx.collect();
    try testing.expect(runtime.lifetime.slotOf(root.node).isEmpty());
    try testing.expect(runtime.lifetime.slotOf(span.node).isEmpty());
    try testing.expect(root.watched.alive());

    // The host hands the CHILD to script again (an operation returning it):
    // a wrapper reaches the tree, and the root has none.
    try WrapAgain.wrap(frame, span.watched.instance);
    try testing.expect(!runtime.lifetime.slotOf(span.node).isEmpty());
    try testing.expect(runtime.lifetime.slotOf(root.node).isEmpty());

    // The realm's end leaves it: script of another realm may hold that
    // wrapper, and the node behind it must stay whole.
    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    queue.drainAll();
    try testing.expect(root.watched.alive());
    try testing.expect(span.watched.alive());
    try testing.expectEqual(dom.NodeBase.ELEMENT_NODE, span.node.node_type);

    // When that wrapper goes, the net frees what only the ended realm's
    // work holds.
    var turns: usize = 0;
    while (turns < 6 and root.watched.alive()) : (turns += 1) {
        fx.collect();
        queue.drainAll();
    }
    try testing.expect(!root.watched.alive());
    try testing.expect(!span.watched.alive());
}

test "a root whose release waits at its realm's end is not freed while a wrapper reaches a child of it" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);

    // A detached <div> script holds, and a <span> in it the TEST holds a
    // wrapper of (as script of another realm would).
    const root = try nodeOf(frame, "globalThis.d = new Document(); globalThis.x = d.createElement('div'); x");
    var reports: Reports = .{};
    const child_wrapper = try engine.evaluateClassicScript(frame, .{ .utf8 = "x.appendChild(d.createElement('span'))" }, "", null, reports.reporter());
    var child_held = true;
    defer if (child_held) child_wrapper.release();
    try testing.expectEqual(@as(usize, 0), reports.count);
    const span_instance = engine.convertToPlatformObject(frame, child_wrapper.value) orelse return error.NotAPlatformObject;
    const span: Made = .{ .watched = Watched.of(span_instance), .node = dom.instance_bridge.getNodeBase(span_instance) orelse return error.NotANode };
    queue.drainAll();
    defer queue.drainAll();

    // The root's wrapper is dropped in the middle of something: its release
    // is recorded and has not run when the realm ends.
    try run(frame, "globalThis.x = null;");
    try fx.scavengeHolding();
    try testing.expect(runtime.lifetime.slotOf(root.node).isEmpty());
    try testing.expect(!runtime.lifetime.slotOf(span.node).isEmpty());

    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    queue.drainAll();
    // The child's wrapper still reaches the tree: it stays whole.
    try testing.expect(span.watched.alive());
    try testing.expect(root.watched.alive());
    try testing.expectEqual(dom.NodeBase.ELEMENT_NODE, span.node.node_type);
    try testing.expect(span.node.parent_node == root.node);

    // The child's wrapper goes: the tree's last hold, so the counts free it.
    child_wrapper.release();
    child_held = false;
    var turns: usize = 0;
    while (turns < 6 and root.watched.alive()) : (turns += 1) {
        fx.collect();
        queue.drainAll();
    }
    try testing.expect(!root.watched.alive());
    try testing.expect(!span.watched.alive());
}

test "a wrapper released inside a shadow tree answers for its host's tree: the net frees the host-including tree of an ended realm" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);

    // A detached host <div> the realm's pending work holds, with a shadow
    // root and a <span> in it.
    const host = try nodeOf(frame,
        \\globalThis.d = new Document();
        \\globalThis.h = d.createElementNS('http://www.w3.org/1999/xhtml', 'div');
        \\globalThis.x = h.attachShadow({ mode: 'open' }).appendChild(d.createElementNS('http://www.w3.org/1999/xhtml', 'span'));
        \\h
    );
    const span = try nodeOf(frame, "x");
    queue.drainAll();
    var pending: dom.node_holds.CountedRef = .{};
    pending.take(host.watched.instance, host.node);
    defer pending.release(host.watched.instance);
    defer queue.drainAll();

    // Every wrapper of the tree goes while the realm lives.
    try run(frame, "globalThis.h = null; globalThis.x = null;");
    fx.collect();
    try testing.expect(runtime.lifetime.slotOf(host.node).isEmpty());
    try testing.expect(runtime.lifetime.slotOf(span.node).isEmpty());
    try testing.expect(host.watched.alive());

    // The host hands the SPAN to script again: the only wrapper of the tree
    // is inside the shadow tree now, and the host has none.
    try WrapAgain.wrap(frame, span.watched.instance);
    try testing.expect(!runtime.lifetime.slotOf(span.node).isEmpty());
    try testing.expect(runtime.lifetime.slotOf(host.node).isEmpty());

    // The realm ends with that wrapper there: the tree stays whole.
    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    queue.drainAll();
    try testing.expect(host.watched.alive());
    try testing.expect(span.watched.alive());

    // Then that wrapper goes. Its release names a node whose root is a
    // shadow root: the tree to look at is its host's.
    var turns: usize = 0;
    while (turns < 6 and host.watched.alive()) : (turns += 1) {
        fx.collect();
        queue.drainAll();
    }
    try testing.expect(!host.watched.alive());
    try testing.expect(!span.watched.alive());
}

test "the roots the net remembers are bounded by the trees that still wait, not by how many it ever declined" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    defer engine.destroyWindowRealm(frame, .global_detached);
    try run(frame, "globalThis.d = new Document();");
    queue.drainAll();

    // 150 trees that wait at once: each declined while the realm lives, its
    // pending work still holding it. All of them are remembered.
    const waiting = 150;
    var pending: [waiting]dom.node_holds.CountedRef = @splat(.{});
    var nodes: [waiting]Made = undefined;
    try run(frame, "globalThis.xs = []; for (let i = 0; i < 150; i++) xs.push(d.createElement('div'));");
    for (&pending, &nodes, 0..) |*hold, *made, i| {
        var source: [32]u8 = undefined;
        made.* = try nodeOf(frame, try std.fmt.bufPrint(&source, "xs[{d}]", .{i}));
        hold.take(made.watched.instance, made.node);
    }
    try run(frame, "globalThis.xs = null;");
    fx.collect();
    for (nodes) |made| try testing.expect(made.watched.alive());
    try testing.expectEqual(@as(i64, waiting), try counterOf(fx, "node_wrapper_net_waiting"));

    // Their work ends: the counts free every one of them.
    for (&pending, nodes) |*hold, made| hold.release(made.watched.instance);
    queue.drainAll();
    for (nodes) |made| try testing.expect(!made.watched.alive());

    // 400 more, one at a time, each declined and then let go by its work.
    var round: usize = 0;
    while (round < 400) : (round += 1) {
        const div = try nodeOf(frame, "globalThis.x = d.createElement('div'); x");
        var hold: dom.node_holds.CountedRef = .{};
        hold.take(div.watched.instance, div.node);
        try run(frame, "globalThis.x = null;");
        ffi.v8_Isolate_RequestGarbageCollection(fx.isolate());
        try testing.expect(div.watched.alive());
        try testing.expect(runtime.lifetime.slotOf(div.node).isEmpty());
        hold.release(div.watched.instance);
        queue.drainAll();
        try testing.expect(!div.watched.alive());
    }
    // Nothing waits now. 550 roots were declined; what is remembered is the
    // remainder since the last sweep, never the history.
    try testing.expect(try counterOf(fx, "node_wrapper_net_waiting") <= 64);
}
