//! The wrapper redesign's P8, folded into P4 (tmp/redesign/wrapper-redesign-
//! design.md 4.11, section 7's P8 entry, risk R3; the user's decision 4,
//! 2026-11-09): node slots are DROPPABLE TracedReferences, and each agent's
//! isolate has an EmbedderRootsHandler - Blink's BlinkRootsHandler
//! (third_party/blink/renderer/platform/heap/thread_state.cc, Chromium
//! 145.0.7608.0). In a young-generation collection V8 then treats a node's
//! slot as weak, not as a root, once its wrapper is an "unmodified API
//! object" (13.1.203 src/handles/traced-handles.cc
//! ComputeWeaknessForYoungObject, src/objects/js-objects.cc
//! JSObject::IsUnmodifiedApiObject): its map still its constructor's initial
//! map, no elements, no identity hash. ResetRoot clears the node's slot and
//! the drain releases the wrapper's reference, as a full collection's weak
//! processing does.
//!
//! What this file pins:
//! - R3, identity: a wrapper script could tell from a fresh one is never
//!   dropped - a WeakMap key, a WeakRef target, a FinalizationRegistry
//!   target, an expando, a changed prototype - through scavenges and full
//!   collections, in a tree and detached, and a wrapper reached only through
//!   another wrapper's tree edge or held through a NodeList, a Range or a
//!   MutationRecord keeps its `===`. V8's rule answered by V8 itself on the
//!   binding's wrapper shape (v8_test_NodeTemplateWrapperDroppable), and the
//!   same uses on script's own wrappers.
//! - The negative control, production since P7 (the wrapper redesign's P5
//!   walk keeps trees, and P7 deleted node tracing's JS edges): an
//!   UNMODIFIED dropped wrapper is freed in a scavenge, its node released,
//!   and the next access makes a fresh wrapper script cannot tell apart;
//!   2,000 of 2,000 lone dropped divs go. Until P7 none was dropped - P4's
//!   tree edges were private properties, a map transition at every wrap -
//!   pinned as a known red that flipped at P7 (until then the negative
//!   control ran with runtime.lifetime's test-only `tree_edges` off).
//! - Kept nodes are never dropped: a keep's root makes the slot
//!   non-droppable.
//!
//! The scavenges are asked for by filling the young generation
//! (v8_test_Isolate_MinorGC: V8 asks for one only with --expose-gc); the
//! full collections are requested ones. The file shares tests/v8's process
//! and makes its own agent per test.

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

    fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
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

    /// Whether `source` evaluates to true.
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

    /// At least `n` scavenges, then the agent's pump - its posted tasks
    /// (FinalizationRegistry cleanups) and its safe point, where the drain a
    /// scavenge owes runs - and its queue.
    fn minorGC(self: Page, n: u32) !void {
        const entered = self.enter();
        defer self.leave(entered);
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), n);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) >= before + n);
        self.pump();
        self.queue.drainAll();
    }

    /// Run the agent's posted platform tasks until none is left.
    fn pump(self: Page) void {
        const entered = self.enter();
        defer self.leave(entered);
        while (ffi.v8_Platform_PumpMessageLoop(self.isolate())) {}
    }

    /// Node wrappers V8 dropped in this agent's scavenges so far.
    fn dropped(self: Page) u64 {
        return ffi.v8_test_NodeWrappers_Dropped(self.isolate());
    }

    /// Scavenges, then full collections, then scavenges again: every check
    /// after each.
    fn collectEveryWay(self: Page, checks: []const []const u8) !void {
        for (0..3) |round| {
            switch (round) {
                0, 2 => try self.minorGC(4),
                else => self.fullGC(),
            }
            for (checks) |check| try self.expectHolds(check);
        }
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

/// `source` evaluated in the page's realm, as the engine handle the probe
/// takes (BORROWED for the duration of `held`).
const Script = struct {
    held: engine.Owned,

    fn of(page: Page, source: []const u8) !Script {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(page.realm, .{ .utf8 = source }, "", null, reports.reporter());
        errdefer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return .{ .held = held };
    }

    fn handle(self: Script) *ffi.Value {
        return @ptrCast(@alignCast(self.held.value.handle.ptr));
    }

    fn release(self: Script) void {
        self.held.release();
    }
};

/// V8's answer for an object made the way the binding makes an
/// HTMLDivElement's wrapper: `with_prototype` sets the global interface's
/// prototype after NewInstance (template_registry.wrapInstanceAsV8Object),
/// `with_edge` adds a private property (node tracing's edges), `apply` is
/// script's use of it.
fn shapeDroppable(page: Page, with_prototype: bool, with_edge: bool, apply: ?[]const u8) !c_int {
    return shapeDroppableOf(page, "HTMLDivElement", with_prototype, with_edge, apply);
}

fn shapeDroppableOf(page: Page, comptime interface: [:0]const u8, with_prototype: bool, with_edge: bool, apply: ?[]const u8) !c_int {
    const entered = page.enter();
    defer page.leave(entered);
    const isolate = page.isolate();
    const context: *ffi.Context = @ptrCast(@alignCast(page.realm.engine_ctx.?));
    const template = v8.template_registry.getTemplateForIsolate(interface, isolate) orelse return error.NoTemplate;
    const prototype = if (with_prototype) ffi.v8_GetGlobalPrototype(context, interface) orelse return error.NoPrototype else null;
    defer if (prototype) |p| ffi.v8_Object_Dispose(p);
    const script: ?Script = if (apply) |source| try Script.of(page, source) else null;
    defer if (script) |s| s.release();
    return ffi.v8_test_NodeTemplateWrapperDroppable(isolate, context, template, prototype, with_edge, if (script) |s| s.handle() else null);
}

test "wr8 R3: V8 drops in a scavenge only a wrapper script cannot tell apart - its unmodified-API-object rule on the binding's wrapper shape" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(
        \\globalThis.wm = new WeakMap(); globalThis.ws = new WeakSet();
        \\globalThis.refs = []; globalThis.fired = [];
        \\globalThis.fr = new FinalizationRegistry((t) => fired.push(t));
        \\globalThis.Other = class extends HTMLElement {};
    );
    // The wrapper as NewInstance makes it, used by nothing: dropped.
    try testing.expectEqual(@as(c_int, 1), try shapeDroppable(page, false, false, null));
    // A private property - node tracing's edges in P4 - is a map transition:
    // never dropped.
    try testing.expectEqual(@as(c_int, 0), try shapeDroppable(page, false, true, null));
    // Every use script could tell apart keeps it.
    const uses = [_][]const u8{
        "(o) => wm.set(o, 1)", // a WeakMap key: an identity hash
        "(o) => ws.add(o)", // a WeakSet member: the same
        "(o) => refs.push(new WeakRef(o))", // a WeakRef target: strong in a scavenge
        "(o) => fr.register(o, 'probe')", // a FinalizationRegistry target: the same
        "(o) => { o.expando = 1; }", // an expando: a map transition
        "(o) => { Object.setPrototypeOf(o, Other.prototype); }", // a changed prototype
        "(o) => { o[0] = 1; }", // an element
        "(o) => { Object.preventExtensions(o); }", // an integrity level: a map transition
    };
    for (uses) |use| {
        const outcome = try shapeDroppable(page, false, false, use);
        if (outcome != 0) std.debug.print("dropped (or inconclusive: {d}) after: {s}\n", .{ outcome, use });
        try testing.expectEqual(@as(c_int, 0), outcome);
    }
}

test "wr8: the binding's own wrapper shape - is setting the global interface's prototype after NewInstance a map transition?" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const outcome = try shapeDroppable(page, true, false, null);
    // A fact for the design (the integrator, 2026-11-09 14:57).
    if (outcome != 1) std.debug.print("wr8 fact: NewInstance + SetPrototype(globalThis.HTMLDivElement.prototype) droppable = {d}\n", .{outcome});
    try testing.expectEqual(@as(c_int, 1), outcome);
}

test "wr8 R3: script's node wrappers keep their identity through scavenges and full collections - WeakMap, WeakRef and FinalizationRegistry, in a tree and detached" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(
        \\globalThis.d = new Document();
        \\d.appendChild(d.createElement('html'));
        \\globalThis.root = d.createElement('section');
        \\globalThis.wm = new WeakMap(); globalThis.refs = {}; globalThis.fired = [];
        \\globalThis.fr = new FinalizationRegistry((t) => fired.push(t));
        \\(() => {
        \\  const inTree = d.documentElement.appendChild(d.createElement('div'));
        \\  const detached = root.appendChild(d.createElement('div'));
        \\  wm.set(inTree, 'in-tree'); wm.set(detached, 'detached');
        \\  const a = d.documentElement.appendChild(d.createElement('p'));
        \\  const b = root.appendChild(d.createElement('p'));
        \\  refs.inTree = new WeakRef(a); refs.detached = new WeakRef(b);
        \\  fr.register(d.documentElement.appendChild(d.createElement('span')), 'in-tree');
        \\  fr.register(root.appendChild(d.createElement('span')), 'detached');
        \\  globalThis.control = new WeakRef({});
        \\})();
    );
    try page.collectEveryWay(&.{
        "wm.get(d.documentElement.querySelector('div')) === 'in-tree' && wm.get(root.querySelector('div')) === 'detached'",
        "refs.inTree.deref() === d.documentElement.querySelector('p') && refs.detached.deref() === root.querySelector('p')",
        "d.documentElement.querySelector('span') !== null && root.querySelector('span') !== null",
    });
    page.pump();
    // The nodes live: no registry callback for them. The control shows the
    // collections and the kept-objects clearing did run.
    try page.expectHolds("fired.length === 0");
    try page.expectHolds("control.deref() === undefined");
}

test "wr8 R3: an expando and a changed prototype survive scavenges and full collections, in a tree and detached" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(
        \\globalThis.d = new Document();
        \\d.appendChild(d.createElement('html'));
        \\globalThis.root = d.createElement('section');
        \\globalThis.Other = class extends HTMLElement {};
        \\d.documentElement.appendChild(d.createElement('div')).expando = 'in-tree';
        \\root.appendChild(d.createElement('div')).expando = 'detached';
        \\Object.setPrototypeOf(d.documentElement.appendChild(d.createElement('p')), Other.prototype);
        \\Object.setPrototypeOf(root.appendChild(d.createElement('p')), Other.prototype);
    );
    try page.collectEveryWay(&.{
        "d.documentElement.querySelector('div').expando === 'in-tree' && root.querySelector('div').expando === 'detached'",
        "Object.getPrototypeOf(d.documentElement.querySelector('p')) === Other.prototype && Object.getPrototypeOf(root.querySelector('p')) === Other.prototype",
    });
}

test "wr8 R3: a wrapper reached only through another wrapper's tree edge, and one held through a NodeList, a Range or a MutationRecord, keeps its ===" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(
        \\globalThis.d = new Document();
        \\globalThis.root = d.createElement('section');
        \\globalThis.seen = new WeakSet();
        \\(() => {
        \\  // Reached only through the tree from `root` (the walk carries it; P4's JS edges did until P7).
        \\  const deep = root.appendChild(d.createElement('div')).appendChild(d.createElement('b'));
        \\  deep.expando = 'deep'; seen.add(deep);
        \\  // A static NodeList, a Range and a MutationRecord hold their nodes.
        \\  const listed = root.appendChild(d.createElement('i')); seen.add(listed);
        \\  globalThis.list = root.querySelectorAll('i');
        \\  const ranged = root.appendChild(d.createElement('u')); seen.add(ranged);
        \\  globalThis.range = d.createRange(); range.selectNode(ranged);
        \\  globalThis.target = d.createElement('ol');
        \\  globalThis.mo = new MutationObserver(() => {});
        \\  mo.observe(target, { childList: true });
        \\  const recorded = target.appendChild(d.createElement('li')); seen.add(recorded);
        \\  target.removeChild(recorded);
        \\})();
        \\globalThis.records = mo.takeRecords();
    );
    try page.collectEveryWay(&.{
        "seen.has(root.firstChild.firstChild) && root.firstChild.firstChild.expando === 'deep'",
        "seen.has(list[0]) && list[0] === root.querySelector('i')",
        "seen.has(range.startContainer.childNodes[range.startOffset]) && range.startContainer.childNodes[range.startOffset] === root.querySelector('u')",
        "records.length === 2 && seen.has(records[1].removedNodes[0]) && records[1].removedNodes[0] === records[0].addedNodes[0]",
    });
}

test "wr8 (P7: no edges, the walk): an unmodified dropped wrapper is freed in a scavenge, its node released, and the next access gets a fresh wrapper script cannot tell apart" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document(); globalThis.root = d.createElement('section');");
    page.fullGC();
    const dropped_before = page.dropped();
    const wrappers_before = try counter(page, "node_wrappers");

    // wrapper-churn-nogc's shape: made and dropped at once, only scavenges.
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(2000); }");
    try page.minorGC(4);
    const dropped_lone = page.dropped() - dropped_before;
    std.debug.print("wr8 fact: lone dropped divs dropped in scavenges = {d} of 2000; live node wrappers +{d}\n", .{ dropped_lone, try counter(page, "node_wrappers") - wrappers_before });
    try testing.expect(dropped_lone >= 1900);
    try testing.expect(try counter(page, "node_wrappers") - wrappers_before < 100);

    // A node that lives on in a tree: its dropped wrapper's reference goes,
    // and script gets a fresh one it cannot tell from the old.
    const b = try page.instance("root.appendChild(d.createElement('b'))");
    const node = dom.instance_bridge.getNodeBase(b) orelse return error.NotANode;
    const watched = SlabAllocator.generationOf(b);
    const count_wrapped = dom.refcount.count(node);
    try page.minorGC(4);
    try testing.expect(runtime.lifetime.slotOf(node).isEmpty());
    try testing.expect(dom.refcount.count(node) < count_wrapped);
    try testing.expectEqual(watched, SlabAllocator.generationOf(b));
    // `d` is an XML document (new Document()): its 'b' is an Element in no
    // namespace, so its prototype is Element.prototype.
    try page.expectHolds("root.firstChild.localName === 'b' && Object.getPrototypeOf(root.firstChild) === Element.prototype && root.firstChild === root.lastChild && Object.keys(root.firstChild).length === 0");
}

test "wr8 P7: with node tracing's JS edges gone, lone dropped divs are dropped in scavenges - 2,000 of 2,000 - on the real path" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document();");
    page.fullGC();
    const dropped_before = page.dropped();
    const wrappers_before = try counter(page, "node_wrappers");
    // Until P7 each wrap drew a private upward edge (wrapper_cache
    // drawDocumentEdge): a map transition, so V8's unmodified-API-object rule
    // never held and none was dropped. With no binding-written property
    // left at wrap time, the production path is the negative control's state
    // above.
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(2000); }");
    try page.minorGC(4);
    const dropped_lone = page.dropped() - dropped_before;
    std.debug.print("wr8 fact (production): lone dropped divs dropped in scavenges = {d} of 2000; live node wrappers +{d}\n", .{ dropped_lone, try counter(page, "node_wrappers") - wrappers_before });
    try testing.expect(dropped_lone >= 1900);
    try testing.expect(try counter(page, "node_wrappers") - wrappers_before < 100);
}

test "wr8: a kept node's wrapper is never dropped in a scavenge - its keep makes the slot non-droppable" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document();");
    // A detached element whose wrapper script drops at once: only its keep
    // (pending activity, a window's document) holds it. With no tree edge
    // (P7) its wrapper is unmodified, so only the keep's non-droppable slot
    // holds it through the scavenges.
    const kept = try page.instance("d.createElement('span')");
    const kept_node = dom.instance_bridge.getNodeBase(kept) orelse return error.NotANode;
    const generation = SlabAllocator.generationOf(kept);
    engine.keepPlatformObjectAlive(kept);
    try page.minorGC(4);
    try testing.expectEqual(generation, SlabAllocator.generationOf(kept));
    try testing.expect(!runtime.lifetime.slotOf(kept_node).isEmpty());
    page.fullGC();
    try testing.expect(!runtime.lifetime.slotOf(kept_node).isEmpty());
    // Its keep ends: a full collection takes the wrapper, and its node goes.
    engine.releasePlatformObject(kept);
    page.fullGC();
    try testing.expect(SlabAllocator.generationOf(kept) != generation);
}

test "wr8: a Document's wrapper is modified at its making - its template's instance has its [LegacyUnforgeable] members - so V8 never drops one" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    // The template's own NewInstance is already not its constructor's
    // initial map: its instance template carries the [LegacyUnforgeable]
    // members (location), which instantiation adds as own properties - map
    // transitions (13.1 ApiNatives::InstantiateObject, ConfigureInstance).
    // Blink's Document wrapper has the same unforgeables on its instance.
    const outcome = try shapeDroppableOf(page, "Document", true, false, null);
    if (outcome != 0) std.debug.print("wr8 fact: a Document template instance droppable = {d}\n", .{outcome});
    try testing.expectEqual(@as(c_int, 0), outcome);
    // And script's own: a dropped Document whose only reference was its
    // wrapper stays through scavenges (a full collection takes it).
    const loose = try page.instance("new Document()");
    const generation = SlabAllocator.generationOf(loose);
    const dropped_before = page.dropped();
    try page.minorGC(4);
    try testing.expectEqual(generation, SlabAllocator.generationOf(loose));
    try testing.expectEqual(dropped_before, page.dropped());
    page.fullGC();
    try testing.expect(SlabAllocator.generationOf(loose) != generation);
}
