//! Inside a callback, the recorded release of a node wrapper is FRESH when
//! the node's slab generation says it was made after the innermost callback
//! began, and it runs at a binding's return into that callback's script
//! (lane mem1, the wrapped-node step of follow-up A).
//!
//! A collection that finds a node wrapper dead records its release
//! (node_wrappers.zig `collected`); until now only the agent's depth-zero
//! safe point or the pump released them (`Registry.drain`), so a garbage
//! tree whose nodes script had wrapped stayed whole until the callback
//! returned: 3,000 delete-joins in one timer callback peaked at 1.9x the
//! same joins spread over callbacks (tests/html/perf1_garbage_weight_test).
//! The frames below the innermost callback were suspended before such a
//! node existed, so none holds it: the argument by which that callback's
//! fresh finalizers and fresh trees already go there. A release only counts:
//! the tree it leaves with no hold is QUEUED (dom.refcount_teardown.settle),
//! and freed only by the queue's own rules.
//!
//! Pinned here: a fresh node's release runs at the binding's return, an old
//! node's waits for depth zero; and each guard holds every release back -
//! a collection's marking window open, a walk holding the agent's teardowns,
//! the registry ended, a fresh release already on the stack, an exception
//! the returning binding left pending.
//!
//! The callback is the queue's own bookkeeping (`enterCallback` with the
//! realm's slab entry, as dom_algorithm.enterCallback makes it), and the
//! scripts run inside it: their bindings return at the callback's depth, as
//! a listener's do. The collections are V8's own (`scavengeHolding`: a young
//! collection with no safe point after it).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const ffi = v8.ffi;
const node_wrappers = v8.node_wrappers;
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

/// One agent with its own deferred teardown queue and a Window realm.
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
        const page = try engine.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .page = page, .queue = queue };
    }

    fn close(self: Fixture) void {
        engine.destroyWindowRealm(self.page, .global_detached);
        engine.destroyAgent(self.agent);
    }

    fn isolate(self: Fixture) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn registry(self: Fixture) !*node_wrappers.Registry {
        return node_wrappers.registryOf(self.isolate()) orelse error.NoRegistry;
    }

    /// A callback invocation begins: its entry is the realm's slab's next
    /// generation (dom_algorithm.enterCallback's `entryOf`).
    fn enterCallback(self: Fixture) !DeferredTeardown.OuterCallback {
        const scope = self.page.browserScope() orelse return error.NoScope;
        return self.queue.enterCallback(.{ .slab = &scope.slab, .generation = scope.slab.generationNow() });
    }

    /// One young-generation collection with NO safe point after it: the
    /// wrappers script let go of are dropped and their releases recorded.
    fn scavengeHolding(self: Fixture) !void {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        defer if (entered) ffi.v8_Isolate_Exit(self.isolate());
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), 1);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) > before);
    }

    /// The agent's depth-zero safe point: every recorded release runs.
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

/// A node `source` evaluates to, and its slab generation: whether it is
/// still there. No wrapper of it is kept here.
const Made = struct {
    instance: *runtime.Instance,
    generation: u64,
    node: *NodeBase,

    fn alive(self: Made) bool {
        return SlabAllocator.generationOf(self.instance) == self.generation;
    }

    /// Its wrapper's reference is still counted: the release waits.
    fn held(self: Made) bool {
        return dom.refcount.count(self.node) != 0;
    }
};

fn nodeOf(realm: runtime.Context, source: []const u8) !Made {
    var reports: Reports = .{};
    const result = try engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, reports.reporter());
    defer result.release();
    try testing.expectEqual(@as(usize, 0), reports.count);
    const instance = engine.convertToPlatformObject(realm, result.value) orelse return error.NotAPlatformObject;
    const node = dom.instance_bridge.getNodeBase(instance) orelse return error.NotANode;
    return .{ .instance = instance, .generation = SlabAllocator.generationOf(instance), .node = node };
}

/// A binding returns into the callback's script: the fresh safe point.
const binding_return = "void globalThis.d.documentElement";

/// The common opening: a Document; an OLD detached element made before the
/// callback; then, inside it, a FRESH one; both dropped by script and their
/// wrappers collected, the releases recorded and not run.
const Opened = struct {
    old: Made,
    fresh: Made,
    outer: DeferredTeardown.OuterCallback,
};

fn openWithBoth(fx: Fixture) !Opened {
    try run(fx.page, "globalThis.d = new Document(); d.appendChild(d.createElement('html'));");
    const old = try nodeOf(fx.page, "globalThis.o = d.createElement('div'); o.appendChild(d.createElement('span')); o");
    fx.safePoint();
    fx.queue.drainAll();
    const outer = try fx.enterCallback();
    const fresh = try nodeOf(fx.page, "globalThis.f = d.createElement('p'); f.appendChild(d.createElement('b')); f");
    try run(fx.page, "globalThis.o = null; globalThis.f = null;");
    try fx.scavengeHolding();
    try testing.expect(runtime.lifetime.slotOf(old.node).isEmpty());
    try testing.expect(runtime.lifetime.slotOf(fresh.node).isEmpty());
    try testing.expect(old.held() and fresh.held());
    return .{ .old = old, .fresh = fresh, .outer = outer };
}

/// The callback returns, the depth-zero safe point releases what waited and
/// the queue frees both trees.
fn closeBoth(fx: Fixture, opened: Opened) !void {
    fx.queue.leaveCallback(opened.outer);
    fx.safePoint();
    fx.queue.drainAll();
    try testing.expect(!opened.old.alive());
    try testing.expect(!opened.fresh.alive());
}

test "inside a callback, a binding's return releases a fresh node wrapper's recorded reference and leaves an old one's for depth zero" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();

    const opened = try openWithBoth(fx);
    try run(fx.page, binding_return);
    // The fresh tree's last reference went: queued, not freed (the queue is
    // under its bounds).
    try testing.expect(!opened.fresh.held());
    try testing.expect(opened.fresh.node.rc_flags.garbage);
    try testing.expect(opened.fresh.alive());
    // The old one's release waits for depth zero.
    try testing.expect(opened.old.held());
    try testing.expect(!opened.old.node.rc_flags.garbage);
    try closeBoth(fx, opened);
}

test "a release recorded while a collection's marking window is open waits, and runs at the next return once it closed" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();

    const opened = try openWithBoth(fx);
    const registry = try fx.registry();
    registry.marking_from = 0;
    try run(fx.page, binding_return);
    registry.marking_from = null;
    try testing.expect(opened.fresh.held());
    try run(fx.page, binding_return);
    try testing.expect(!opened.fresh.held());
    try testing.expect(opened.old.held());
    try closeBoth(fx, opened);
}

test "a walk holding the agent's teardowns holds the fresh releases back; its resume releases them" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();

    const opened = try openWithBoth(fx);
    engine.deferTeardowns(fx.page);
    // No script runs under a hold: the binding's return is the queue's.
    {
        const entered = ffi.v8_Isolate_GetCurrent() != fx.isolate();
        if (entered) ffi.v8_Isolate_Enter(fx.isolate());
        defer if (entered) ffi.v8_Isolate_Exit(fx.isolate());
        fx.queue.enterAlgorithm();
        fx.queue.leaveAlgorithmToScript();
    }
    try testing.expect(opened.fresh.held());
    try testing.expect(opened.old.held());
    // The last resume drains every recorded release (node_wrappers.drainOf).
    engine.resumeTeardowns(fx.page);
    try testing.expect(!opened.fresh.held());
    try closeBoth(fx, opened);
}

test "an ended registry releases nothing at a callback's binding return" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();

    const opened = try openWithBoth(fx);
    const registry = try fx.registry();
    registry.ended = true;
    try run(fx.page, binding_return);
    registry.ended = false;
    try testing.expect(opened.fresh.held());
    try testing.expect(opened.old.held());
    try closeBoth(fx, opened);
}

test "a fresh release already on the stack makes a nested binding return release nothing" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();

    const opened = try openWithBoth(fx);
    const registry = try fx.registry();
    registry.releasing_fresh = true;
    try run(fx.page, binding_return);
    registry.releasing_fresh = false;
    try testing.expect(opened.fresh.held());
    // Still owed: the next return releases it.
    try run(fx.page, binding_return);
    try testing.expect(!opened.fresh.held());
    try testing.expect(opened.old.held());
    try closeBoth(fx, opened);
}

test "a binding that returns with its exception pending releases nothing; the next normal return does" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const fx = try Fixture.open(&queue);
    defer fx.close();

    const opened = try openWithBoth(fx);
    // createElement throws InvalidCharacterError: its binding returns with
    // the exception pending, which engine work would clear. (The catch
    // block calls no binding: one would be the next normal return.)
    try run(fx.page, "try { d.createElement('1 not a name'); } catch (e) {}");
    try testing.expect(opened.fresh.held());
    try run(fx.page, binding_return);
    try testing.expect(!opened.fresh.held());
    try testing.expect(opened.old.held());
    try closeBoth(fx, opened);
}
