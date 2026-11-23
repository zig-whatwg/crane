//! Refcount step 7b: a realm's end frees no node whatever its counts (lane
//! rc7b; tmp/plans/refcount9-design.md B4). This file was lane wr1 batch
//! 11's tests of step 7a's ended-realm net and its hole (node_wrappers.zig
//! `endedRealmNet`, `endRealm`): a detached tree of a realm that ended,
//! still held by a counted reference, was freed whatever its counts once no
//! wrapper reached it. 7b removes the net: the realm's end lets go of the
//! realm's OWN references (its Window's, its documents' tasks, its watchers)
//! and the counts decide the rest - a counted reference another realm holds
//! (here the test's `CountedRef`, as an event's touch target list or a
//! record of another realm would) keeps its tree, whole, past the realm's
//! end, and the tree is freed by the agent's deferred teardown queue when
//! that reference ends. WebKit and Blink keep such a node past its frame.
//!
//! What these pin, in the shapes the net's tests had:
//! 1. a detached root (and a tree held through a child) whose wrapper was
//!    released while the realm lived outlives the realm's end, and goes
//!    when its hold does;
//! 2. the wrapper outlives the realm: its release leaves the tree to the
//!    hold;
//! 3. a tree a wrapper reaches stays whole through the realm's end, a root
//!    whose release was still owed at the end included (the end runs the
//!    realm's owed releases first: node_wrappers.releaseRealm);
//! 4. a wrapper inside a shadow tree answers for its host's tree;
//! 5. many held trees: every one outlives the realm's end, and every one is
//!    freed when its hold ends.
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
            .agent_cluster_cross_origin_isolated = true,
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

test "a detached root another holder counts, its wrapper released while its realm lived, outlives the realm's end and is freed when the hold ends" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);

    const div = try nodeOf(frame, "globalThis.d = new Document(); globalThis.x = d.createElement('div'); x");
    queue.drainAll();
    // A counted reference the realm does not own: another realm's holder.
    var held: dom.node_holds.CountedRef = .{};
    held.take(div.watched.instance, div.node);
    defer held.release(div.watched.instance);
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

    // The realm ends: no script of it runs again. The hold is not the
    // realm's, so the tree stays.
    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    queue.drainAll();
    try testing.expect(div.watched.alive());
    try testing.expectEqual(dom.NodeBase.ELEMENT_NODE, div.node.node_type);
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(div.node));

    // The hold ends: the counts free the tree, in a slice of the queue.
    held.release(div.watched.instance);
    queue.drainAll();
    try testing.expect(!div.watched.alive());
}

test "a detached tree another holder counts through a child - the root never held - outlives its realm's end and is freed when the hold ends" {
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
    var held: dom.node_holds.CountedRef = .{};
    held.take(img.watched.instance, img.node);
    defer held.release(img.watched.instance);
    defer queue.drainAll();

    try run(frame, "globalThis.x = null;");
    fx.collect();
    // Both wrappers went; the hold on the img keeps the tree.
    try testing.expect(root.watched.alive());
    try testing.expect(img.watched.alive());
    try testing.expect(runtime.lifetime.slotOf(root.node).isEmpty());
    try testing.expect(runtime.lifetime.slotOf(img.node).isEmpty());
    try testing.expect(queue.isEmpty());

    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    queue.drainAll();
    try testing.expect(img.watched.alive());
    try testing.expect(root.watched.alive());
    try testing.expect(img.node.parent_node == root.node);

    held.release(img.watched.instance);
    queue.drainAll();
    try testing.expect(!img.watched.alive());
    try testing.expect(!root.watched.alive());
}

test "a wrapper that outlives its realm leaves the tree to another holder's count when it goes, and that count's end frees it" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);

    const div = try nodeOf(frame, "globalThis.d = new Document(); globalThis.x = d.createElement('div'); x");
    queue.drainAll();
    var held: dom.node_holds.CountedRef = .{};
    held.take(div.watched.instance, div.node);
    defer held.release(div.watched.instance);
    defer queue.drainAll();

    // The realm ends with the wrapper still there (its global held it).
    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    // The collections after it take the wrapper; its release leaves the
    // tree to the hold.
    var turns: usize = 0;
    while (turns < 6 and !runtime.lifetime.slotOf(div.node).isEmpty()) : (turns += 1) {
        fx.collect();
        queue.drainAll();
    }
    try testing.expect(runtime.lifetime.slotOf(div.node).isEmpty());
    try testing.expect(div.watched.alive());
    try testing.expectEqual(@as(u32, 1), dom.refcount.count(div.node));

    held.release(div.watched.instance);
    queue.drainAll();
    try testing.expect(!div.watched.alive());
}

test "a tree a wrapper reaches stays whole through its realm's end; once the wrapper and the hold are gone the counts free it" {
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
    var held: dom.node_holds.CountedRef = .{};
    held.take(span.watched.instance, span.node);
    defer held.release(span.watched.instance);
    defer queue.drainAll();

    // Both wrappers released while the realm lives.
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

    // The wrapper goes: the hold still keeps the tree.
    var turns: usize = 0;
    while (turns < 6 and !runtime.lifetime.slotOf(span.node).isEmpty()) : (turns += 1) {
        fx.collect();
        queue.drainAll();
    }
    try testing.expect(runtime.lifetime.slotOf(span.node).isEmpty());
    try testing.expect(root.watched.alive());
    try testing.expect(span.node.parent_node == root.node);

    held.release(span.watched.instance);
    queue.drainAll();
    try testing.expect(!root.watched.alive());
    try testing.expect(!span.watched.alive());
}

test "a root whose release was still owed at its realm's end stays whole while a wrapper reaches a child of it" {
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

test "a wrapper inside a shadow tree keeps its host's whole tree through its realm's end; with it and the hold gone the counts free the tree" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);

    // A detached host <div> another holder counts, with a shadow root and a
    // <span> in it.
    const host = try nodeOf(frame,
        \\globalThis.d = new Document();
        \\globalThis.h = d.createElementNS('http://www.w3.org/1999/xhtml', 'div');
        \\globalThis.x = h.attachShadow({ mode: 'open' }).appendChild(d.createElementNS('http://www.w3.org/1999/xhtml', 'span'));
        \\h
    );
    const span = try nodeOf(frame, "x");
    queue.drainAll();
    var held: dom.node_holds.CountedRef = .{};
    held.take(host.watched.instance, host.node);
    defer held.release(host.watched.instance);
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

    // Then that wrapper goes: the hold on the host keeps the tree.
    var turns: usize = 0;
    while (turns < 6 and !runtime.lifetime.slotOf(span.node).isEmpty()) : (turns += 1) {
        fx.collect();
        queue.drainAll();
    }
    try testing.expect(runtime.lifetime.slotOf(span.node).isEmpty());
    try testing.expect(host.watched.alive());
    try testing.expect(span.watched.alive());

    held.release(host.watched.instance);
    queue.drainAll();
    try testing.expect(!host.watched.alive());
    try testing.expect(!span.watched.alive());
}

test "many held detached trees all outlive their realm's end, and each is freed when its hold ends" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();
    const frame = try fx.frame();
    var frame_ended = false;
    defer if (!frame_ended) engine.destroyWindowRealm(frame, .global_detached);
    try run(frame, "globalThis.d = new Document();");
    queue.drainAll();

    const count = 150;
    var holds: [count]dom.node_holds.CountedRef = @splat(.{});
    var nodes: [count]Made = undefined;
    try run(frame, "globalThis.xs = []; for (let i = 0; i < 150; i++) xs.push(d.createElement('div'));");
    for (&holds, &nodes, 0..) |*hold, *made, i| {
        var source: [32]u8 = undefined;
        made.* = try nodeOf(frame, try std.fmt.bufPrint(&source, "xs[{d}]", .{i}));
        hold.take(made.watched.instance, made.node);
    }
    defer for (&holds, nodes) |*hold, made| hold.release(made.watched.instance);
    defer queue.drainAll();
    try run(frame, "globalThis.xs = null;");
    fx.collect();
    for (nodes) |made| try testing.expect(made.watched.alive());

    engine.destroyWindowRealm(frame, .global_detached);
    frame_ended = true;
    queue.drainAll();
    for (nodes) |made| try testing.expect(made.watched.alive());

    // Half the holds end: exactly those trees go.
    for (holds[0 .. count / 2], nodes[0 .. count / 2]) |*hold, made| hold.release(made.watched.instance);
    queue.drainAll();
    for (nodes[0 .. count / 2]) |made| try testing.expect(!made.watched.alive());
    for (nodes[count / 2 ..]) |made| try testing.expect(made.watched.alive());
    for (holds[count / 2 ..], nodes[count / 2 ..]) |*hold, made| hold.release(made.watched.instance);
    queue.drainAll();
    for (nodes) |made| try testing.expect(!made.watched.alive());
}
