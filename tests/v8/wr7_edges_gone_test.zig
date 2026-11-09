//! The wrapper redesign's P7 (tmp/redesign/wrapper-redesign-design.md section
//! 7's P7 entry, 3.4 and 4.1): node tracing's JS edges go. Until P7 every node
//! wrapper got a private upward edge at its wrap - to its parent's wrapper,
//! or its node document's for a root (wrapper_cache drawTreeEdges /
//! drawDocumentEdge) - its parent's wrapper a JS Set of its wrapped children
//! (`crane:tree:children`), and the wrapped part of a tree was upward-closed:
//! a wrap wrapped every unwrapped ancestor first, so the edges reached the
//! root. From P7 the walk alone keeps trees (dom.wrapper_tracing, reached
//! from NodeAnchor::Trace in the collector's atomic pause), as Blink's
//! Node::Trace does through its Member edges - no property on any wrapper
//! (Chromium 131.0.6778.0: ScriptWrappable::Trace visits `wrapper_`, nothing
//! is written to the wrapper's object).
//!
//! What this file pins:
//! - a query wraps exactly its results: gc_bench `qsa-deep`'s shape (1,000
//!   leaves at depth 12 under 119 ancestors) makes 1,000 node wrappers for
//!   reading its 1,000 results, not 1,119 (before P7 each leaf's wrap
//!   wrapped its 11 unwrapped ancestors - the upward closure);
//! - a wrapped node costs its parent's wrapper no Set entry and itself no
//!   upward edge: neither wrapper is modified, so V8 drops both in a
//!   scavenge once script drops them, while the nodes live on in their tree
//!   (the redesign's P8 droppable slots, Blink's BlinkRootsHandler);
//! - a node read out of a parsed tree wraps none of its ancestors.
//!
//! Each test makes its own agent (tests/v8 shares one process).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const DeferredTeardown = runtime.gc.DeferredTeardown;
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
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm, .queue = queue };
    }

    /// The Browser's end, in its order (Browser.deinit): the realm, every
    /// node wrapper's reference, the last drain, then the agent.
    fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.releaseNodeWrappers(self.agent);
        self.queue.drainAll();
        engine.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn holds(self: Page, source: []const u8) !bool {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return engine.toBoolean(self.realm, held.value);
    }

    fn expectHolds(self: Page, source: []const u8) !void {
        if (!try self.holds(source)) {
            std.debug.print("does not hold: {s}\n", .{source});
            return error.TestExpectedTrue;
        }
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return engine.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    fn enter(self: Page) bool {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        return entered;
    }

    fn leave(self: Page, entered: bool) void {
        if (entered) ffi.v8_Isolate_Exit(self.isolate());
    }

    /// Requested full collections, twice, their releases drained and the
    /// garbage trees freed.
    fn fullGC(self: Page) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        self.queue.drainAll();
    }

    /// At least `n` scavenges, then the agent's posted tasks and its queue.
    fn minorGC(self: Page, n: u32) !void {
        const entered = self.enter();
        defer self.leave(entered);
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), n);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) >= before + n);
        while (ffi.v8_Platform_PumpMessageLoop(self.isolate())) {}
        self.queue.drainAll();
    }

    /// Node wrappers V8 dropped in this agent's scavenges so far.
    fn dropped(self: Page) u64 {
        return ffi.v8_test_NodeWrappers_Dropped(self.isolate());
    }
};

/// The adapter's counter `name` with the page's isolate entered.
fn counter(page: Page, name: []const u8) !i64 {
    const entered = page.enter();
    defer page.leave(entered);
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    std.debug.print("the adapter reports no counter named {s}\n", .{name});
    return error.CounterMissing;
}

/// The wrappers `source` makes: the engine's wrapper creations (gc_bench's
/// `wrappers_per_cycle` reads the same counter).
fn wrappersMadeBy(page: Page, source: []const u8) !i64 {
    const name = "object_globals_from.ObjectTemplate_NewInstance";
    const before = try counter(page, name);
    try page.run(source);
    return try counter(page, name) - before;
}

/// gc_bench `qsa-deep`'s tree (tools/gc_bench_options.zig): 1,000 `b`
/// leaves at depth 12 - each under an `i`, a `u` and nine `div`s - 1,119
/// elements in all, none of them wrapped by the parse.
const qsa_deep_tree =
    \\globalThis.qsaDeepHtml = (() => {
    \\  let s = '<b></b>'.repeat(10); s = ('<i>' + s + '</i>').repeat(10); s = ('<u>' + s + '</u>').repeat(10);
    \\  for (let d = 0; d < 9; d++) s = '<div>' + s + '</div>';
    \\  return s;
    \\})();
    \\globalThis.h = new Document().implementation.createHTMLDocument('wr7');
;

test "wr7 RED: a query wraps exactly its results - qsa-deep's 1,000 leaves make 1,000 node wrappers, none for their 119 ancestors" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(qsa_deep_tree);
    // The tree, the query and its list, nothing read: the control.
    const control = try wrappersMadeBy(page, "{ const c = h.createElement('div'); c.innerHTML = qsaDeepHtml; const l = c.querySelectorAll('b'); void l.length; }");
    // gc_bench qsa-deep's cycle: the same, each result read once.
    const cycle = try wrappersMadeBy(page, "{ const c = h.createElement('div'); c.innerHTML = qsaDeepHtml; const l = c.querySelectorAll('b'); for (let k = 0; k < l.length; k++) void l[k]; }");
    std.debug.print("wr7 fact: qsa-deep's cycle made {d} wrappers, its control {d}: {d} for 1,000 results\n", .{ cycle, control, cycle - control });
    try testing.expectEqual(@as(i64, 1000), cycle - control);
}

test "wr7 RED: a node read out of a parsed tree wraps none of its ancestors, and an insertion under it none either" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(
        \\globalThis.h = new Document().implementation.createHTMLDocument('wr7');
        \\globalThis.root = h.createElement('section');
        \\root.innerHTML = '<div><p><i></i></p></div>';
        \\globalThis.leaf = root.querySelector('i');
        \\leaf.appendChild(h.createElement('b'));
    );
    const leaf = dom.instance_bridge.getNodeBase(try page.instance("leaf")) orelse return error.NotANode;
    const p = leaf.parent_node orelse return error.NoParent;
    const div = p.parent_node orelse return error.NoParent;
    try testing.expect(!leaf.wrapper.isEmpty());
    // Neither ancestor between the wrapped root and the wrapped leaf.
    try testing.expect(p.wrapper.isEmpty());
    try testing.expect(div.wrapper.isEmpty());
    // The walk keeps the tree's wrappers all the same.
    try page.run("leaf.wr7 = 'leaf'; root.wr7 = 'root'; leaf.firstChild.wr7 = 'b'; globalThis.leaf = null;");
    page.fullGC();
    try page.expectHolds("root.querySelector('i').wr7 === 'leaf' && root.wr7 === 'root' && root.querySelector('b').wr7 === 'b'");
}

test "wr7 RED: a wrapped node costs its parent's wrapper no Set entry and itself no upward edge - both stay droppable in a scavenge" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(
        \\globalThis.d = new Document();
        \\globalThis.root = d.createElement('section');
        \\globalThis.p = root.appendChild(d.createElement('div'));
        \\globalThis.c = p.appendChild(d.createElement('span'));
    );
    const root = try page.instance("root");
    const parent = try page.instance("p");
    const child = try page.instance("c");
    // No upward edge on any of the three: before P7 a node in a tree held
    // its parent's wrapper, a root its node document's, in this one slot.
    for ([_]*runtime.Instance{ root, parent, child }) |node| {
        if (engine.tracedValue(node, dom.node_document.traced_slot)) |edge| {
            edge.release();
            return error.UpwardEdgeDrawn;
        }
    }
    // No Set of wrapped children on the parent's wrapper or the root's.
    try testing.expect(!try hasPrivate(page, "p", "crane:tree:children"));
    try testing.expect(!try hasPrivate(page, "root", "crane:tree:children"));

    // So neither wrapper is modified: once script drops them, a scavenge
    // takes both, and the nodes live on in `root`'s tree.
    const parent_node = dom.instance_bridge.getNodeBase(parent) orelse return error.NotANode;
    const child_node = dom.instance_bridge.getNodeBase(child) orelse return error.NotANode;
    const dropped_before = page.dropped();
    try page.run("globalThis.p = null; globalThis.c = null;");
    try page.minorGC(4);
    try testing.expect(page.dropped() - dropped_before >= 2);
    try testing.expect(runtime.lifetime.slotOf(parent_node).isEmpty());
    try testing.expect(runtime.lifetime.slotOf(child_node).isEmpty());
    try page.expectHolds("root.firstChild.localName === 'div' && root.firstChild.firstChild.localName === 'span' && Object.keys(root.firstChild).length === 0");
}

/// Whether the wrapper `expression` evaluates to has the private property
/// `key` (the adapter's private-symbol namespace).
fn hasPrivate(page: Page, expression: []const u8, key: []const u8) !bool {
    var reports: Reports = .{};
    const held = try engine.evaluateClassicScript(page.realm, .{ .utf8 = expression }, "", null, reports.reporter());
    defer held.release();
    try testing.expectEqual(@as(usize, 0), reports.count);
    const Read = struct {
        holder: *ffi.Object,
        key: []const u8,
        found: bool = false,

        fn steps(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const value = ffi.v8_Object_GetPrivateRef(self.holder, self.key.ptr, @intCast(self.key.len)) orelse return;
            ffi.v8_Global_Dispose(value);
            self.found = true;
        }
    };
    var read: Read = .{ .holder = @ptrCast(@alignCast(held.value.handle.ptr)), .key = key };
    try engine.runInRealm(page.realm, Read.steps, &read);
    return read.found;
}
