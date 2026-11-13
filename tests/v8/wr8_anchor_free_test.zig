//! The wrapper redesign's P8, lane wr1 batch 8: a node anchor whose wrapper V8
//! dropped in a young-generation collection is freed after that collection,
//! not at the next full one.
//!
//! P8 (tests/v8/wr8_young_generation_test.zig) lets V8 drop an unmodified
//! node wrapper in a scavenge: the isolate's EmbedderRootsHandler::ResetRoot
//! empties the node's slot - V8 frees the TracedNode - and the drain releases
//! the wrapper's reference. The wrapper's NodeAnchor, 16 bytes of the agent's
//! C++ heap then (24 with the registry index below), and its slot in the
//! anchors' registry waited for the next FULL
//! collection, which V8 schedules rarely: gc_bench's wrapper-churn-nogc held
//! 15.47 B of C++ heap per element where P2 held none, and the full
//! collection's pause grew with the anchors waiting for it (lane wr1 batch 7,
//! tmp/plans/lane-wr1-handoff.md). The integrator's option (a), 2026-11-09
//! 23:48 UTC: free each such anchor in the drain after the scavenge, outside
//! any collection, with cppgc::subtle::FreeUnreferencedObject, and take it out
//! of the registry in O(1) through an index the anchor holds. cppgc refuses
//! the free - a silent no-op - while its heap is collecting (13.1.203
//! src/heap/cppgc/explicit-management.cc InGC: the atomic pause, a marker, or
//! sweeping in progress); a refused free is counted and the anchor goes later,
//! never leaks.
//!
//! What this file pins:
//! - the counters that separate a full collection's pause (the anchors' weak
//!   processing - its time and slots - and the atomic pause's phases, whole
//!   heap and C++ heap, as V8 reports them to the isolate's metrics recorder);
//! - wrapper churn with only scavenges leaves the C++ heap and the anchors'
//!   registry where they began: no anchor waits for a full collection;
//! - a free refused while the C++ heap is collecting (here: still sweeping
//!   after a full collection V8 did not force) is counted, and its anchor
//!   goes with the next full collection;
//! - a node whose wrapper was dropped is wrapped again with a fresh anchor,
//!   and each anchor is freed exactly once.
//!
//! The scavenges are asked for by filling the young generation
//! (v8_test_Isolate_MinorGC); the full collections are requested ones. The
//! file shares tests/v8's process and makes its own agent per test.

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

    /// At least `n` scavenges, nothing run after them: the drain they owe
    /// waits for the agent's next safe point (`pump`'s).
    fn scavenge(self: Page, n: u32) !void {
        const entered = self.enter();
        defer self.leave(entered);
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), n);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) >= before + n);
    }

    /// At least `n` scavenges, then the agent's pump - its posted tasks and
    /// its safe point, where the drain a scavenge owes runs - and its queue.
    fn minorGC(self: Page, n: u32) !void {
        try self.scavenge(n);
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

    fn probe(self: Page, node: *dom.NodeBase) ffi.NodeWrapperProbe {
        const entered = self.enter();
        defer self.leave(entered);
        var seen: ffi.NodeWrapperProbe = undefined;
        ffi.v8_test_NodeWrapper_Probe(self.isolate(), @ptrCast(runtime.lifetime.slotOf(node)), &seen);
        return seen;
    }
};

/// The adapter's counter `name` with the page's isolate entered (the
/// anchors' and the C++ heap's figures are the current isolate's).
fn counter(page: Page, name: []const u8) !i64 {
    const entered = page.enter();
    defer page.leave(entered);
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    std.debug.print("the adapter reports no counter named {s}\n", .{name});
    return error.CounterMissing;
}

/// The bytes alive on the page's C++ heap, object by object.
fn liveBytes(page: Page) i64 {
    const entered = page.enter();
    defer page.leave(entered);
    return @intCast(ffi.v8_test_CppHeap_LiveBytes(page.isolate()));
}

/// The anchors not yet freed: in the registry, or dropped and waiting.
fn anchorsHeld(page: Page) !i64 {
    return try counter(page, "node_anchors_registered") + try counter(page, "node_anchors_dropped_waiting");
}

test "wr8 b8: a full collection's anchor weak processing and its atomic pause's phases are counted" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    // 1,000 wrapped divs, kept by script: 1,000 anchors in the registry.
    try page.run("globalThis.d = new Document(); globalThis.kept = (() => { const a = []; for (let i = 0; i < 1000; i++) a.push(d.createElement('div')); return a; })();");
    page.fullGC();
    try testing.expect(try counter(page, "node_anchors_registered") >= 1000);
    // The anchors' weak processing read every one of them, and took time.
    try testing.expect(try counter(page, "node_anchor_weak_slots_max") >= 1000);
    try testing.expect(try counter(page, "node_anchor_weak_ns_max") > 0);
    // The atomic pause's phases are reported: by V8's metrics recorder in
    // gc_bench's build, where gcdiag reads them; 0 in this one, whose isolates
    // have no recorder (v8_wrapper.cpp CRANE_GC_PHASE_METRICS: V8 would keep a
    // weak global handle per context for it).
    for ([_][]const u8{ "gc_atomic_us_max", "gc_atomic_mark_us_max", "gc_atomic_weak_us_max", "gc_atomic_compact_us_max", "gc_atomic_sweep_us_max", "cpp_atomic_us_max", "cpp_atomic_mark_us_max", "cpp_atomic_weak_us_max", "cpp_atomic_compact_us_max", "cpp_atomic_sweep_us_max" }) |name| {
        try testing.expect(try counter(page, name) >= 0);
    }
    try page.run("globalThis.kept = null;");
    page.fullGC();
}

test "wr8 b8: wrapper churn with only scavenges leaves the C++ heap and the anchors' registry where they began - no anchor waits for a full collection" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document();");
    page.fullGC();
    const full_before = try counter(page, "full_gc_count");
    const held_before = try anchorsHeld(page);
    const cpp_before = liveBytes(page);
    const dropped_before = page.dropped();

    // wrapper-churn-nogc's shape: made and dropped at once.
    const count = 50_000;
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(50000); }");
    try page.minorGC(4);
    const dropped = page.dropped() - dropped_before;
    const held = try anchorsHeld(page) - held_before;
    const cpp = liveBytes(page) - cpp_before;
    std.debug.print("wr8 b8 fact: {d} of {d} dropped in scavenges; anchors held +{d}; C++ heap +{d} B ({d:.2} B/elem); freed {d}, frees deferred {d}\n", .{
        dropped,                                                       count,                                   held,                                            cpp,
        @as(f64, @floatFromInt(cpp)) / @as(f64, @floatFromInt(count)), try counter(page, "node_anchors_freed"), try counter(page, "node_anchor_frees_deferred"),
    });
    // Only scavenges ran: this is the young generation's path.
    try testing.expectEqual(full_before, try counter(page, "full_gc_count"));
    try testing.expect(dropped >= count - 1000);
    // Every dropped wrapper's anchor is gone from the registry and freed.
    try testing.expect(held < 1000);
    // ~0 B/element of C++ heap, counted object by object (cpp_heap_used_bytes
    // counts a whole allocation buffer from the moment it is taken, and an
    // explicit free only at the next allocation's safepoint): 50,000 anchors
    // left waiting would be 1.2 MB. Beyond the anchors still held (24 bytes
    // each), at most a few objects' worth.
    try testing.expect(cpp < held * 24 + 16 * 1024);
}

test "wr8 b8: a free refused while the C++ heap is collecting is counted, and its anchor goes with the next full collection - never leaked" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document();");
    page.fullGC();
    const held_before = try anchorsHeld(page);
    const cpp_before = try counter(page, "cpp_heap_used_bytes");
    const deferred_before = try counter(page, "node_anchor_frees_deferred");

    // A full collection V8 does not force - its answer to critical memory
    // pressure - of 100,000 dead wrappers: its C++ heap sweeps on after it,
    // concurrently and then on the agent's thread (15.7.112.43 cpp-heap.cc
    // CppHeap::SelectSweepingType; cppgc-internal/sweeper.cc SweeperImpl::Start
    // posts a low-priority foreground task and a regular one 100 ms later;
    // the anchors' finalizers run only on the agent's thread), so cppgc
    // refuses every free until its pages are finalized.
    try page.run("globalThis.keep = (() => { const a = []; for (let i = 0; i < 100000; i++) a.push(d.createElement('div')); return a; })();");
    try page.run("globalThis.keep = null;");
    {
        const entered = page.enter();
        defer page.leave(entered);
        try testing.expect(ffi.v8_test_Isolate_CollectUnforced(page.isolate()));
    }
    // Wrappers dropped in a scavenge meanwhile, and the agent's safe point
    // INSIDE the task (a binding's return into script: the next scavenge's
    // start owed the drain, as V8's own second passes would run there) while
    // the C++ heap still sweeps: each refused free is counted, and its
    // anchor waits. Not the pump: on V8 15.7 the sweeper's own foreground
    // task is ahead of the drain's in the agent's queue, so a pump finishes
    // the sweep first and no free is refused (lane wr1 b11, the merge onto
    // 15.7; on 13.1.203 the sweep waited for an idle task or 100 ms).
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(5000); }");
    try page.scavenge(2);
    const waiting = try counter(page, "node_anchors_dropped_waiting");
    {
        const entered = page.enter();
        defer page.leave(entered);
        _ = ffi.v8_Isolate_RunQueuedFinalizers(page.isolate());
    }
    const deferred = try counter(page, "node_anchor_frees_deferred") - deferred_before;
    std.debug.print("wr8 b8 fact: {d} anchors waiting after the scavenge; {d} frees refused while the C++ heap swept; {d} still waiting\n", .{ waiting, deferred, try counter(page, "node_anchors_dropped_waiting") });
    try testing.expect(waiting > 0);
    try testing.expect(deferred > 0);
    try testing.expect(try counter(page, "node_anchors_dropped_waiting") > 0);

    // The next full collection: the anchors nothing reached die in it, none
    // waits, and the C++ heap is back where it began - nothing leaked.
    page.fullGC();
    try testing.expectEqual(@as(i64, 0), try counter(page, "node_anchors_dropped_waiting"));
    try testing.expect(try anchorsHeld(page) - held_before < 10);
    try testing.expect(try counter(page, "cpp_heap_used_bytes") - cpp_before < 4096);
}

test "wr11: a free refused while the C++ heap swept is made once the pump has run the sweeper's task - with no further collection" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document();");
    page.fullGC();
    const deferred_before = try counter(page, "node_anchor_frees_deferred");

    // As the test above: a collection V8 does not force leaves its C++ heap
    // sweeping, wrappers are dropped in scavenges meanwhile, and the agent's
    // safe point inside the task finds every free refused.
    try page.run("globalThis.keep = (() => { const a = []; for (let i = 0; i < 100000; i++) a.push(d.createElement('div')); return a; })();");
    try page.run("globalThis.keep = null;");
    {
        const entered = page.enter();
        defer page.leave(entered);
        try testing.expect(ffi.v8_test_Isolate_CollectUnforced(page.isolate()));
    }
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(5000); }");
    try page.scavenge(2);
    {
        const entered = page.enter();
        defer page.leave(entered);
        _ = ffi.v8_Isolate_RunQueuedFinalizers(page.isolate());
    }
    const waiting = try counter(page, "node_anchors_dropped_waiting");
    try testing.expect(try counter(page, "node_anchor_frees_deferred") - deferred_before > 0);
    try testing.expect(waiting > 0);

    // The event loop's pump runs V8's tasks - the C++ heap's sweeper among
    // them (15.7 finishes its sweep in foreground tasks) - and the pump that
    // ran one tries the refused frees again (v8_wrapper.cpp
    // `oweWaitingAnchorFrees`): no collection has to come first. Until lane
    // wr1 b11 a task the collection's epilogue posted did that; with the
    // releases owed by the collection itself nothing else would, and the
    // anchors would wait for the next collection that dropped a wrapper.
    const freed_before = try counter(page, "node_anchors_freed");
    const collections = try counter(page, "full_gc_count") + try counter(page, "minor_gc_count");
    page.pump();
    try testing.expectEqual(collections, try counter(page, "full_gc_count") + try counter(page, "minor_gc_count"));
    try testing.expectEqual(@as(i64, 0), try counter(page, "node_anchors_dropped_waiting"));
    try testing.expectEqual(waiting, try counter(page, "node_anchors_freed") - freed_before);
    page.fullGC();
}

/// What a full collection's end saw of the table-entry figure.
const TableAtEpilogue = struct {
    isolate: *ffi.Isolate,
    seen: usize = 0,
    bytes: u64 = std.math.maxInt(u64),

    fn onEpilogue(data: ?*anyopaque) callconv(.c) void {
        const self: *TableAtEpilogue = @ptrCast(@alignCast(data.?));
        self.seen += 1;
        self.bytes = ffi.v8_Debug_NodeWrapperTableBytes(self.isolate);
    }
};

test "wr11: V8 is told of the pointer-table entry each dropped wrapper leaves, and a full collection takes the figure back before it ends" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document();");
    page.fullGC();
    try testing.expectEqual(@as(i64, 0), try counter(page, "node_wrapper_table_bytes"));
    const dropped_before = page.dropped();

    // 5,000 wrappers made and let go, dropped by young-generation
    // collections: each leaves its 8-byte CppHeapPointerTable entry until a
    // full collection sweeps the table, and V8 counts the table toward no
    // limit of its own. The agent's drain reports them.
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(5000); }");
    try page.minorGC(2);
    const dropped = page.dropped() - dropped_before;
    try testing.expect(dropped >= 4990);
    try testing.expectEqual(@as(i64, @intCast(dropped * 8)), try counter(page, "node_wrapper_table_bytes"));

    // A second batch adds to the figure.
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(3000); }");
    try page.minorGC(2);
    const dropped_twice = page.dropped() - dropped_before;
    try testing.expect(dropped_twice >= dropped + 2990);
    try testing.expectEqual(@as(i64, @intCast(dropped_twice * 8)), try counter(page, "node_wrapper_table_bytes"));

    // A full collection sweeps the table. The figure is taken back as that
    // collection BEGINS - V8 sets its next limit before its epilogue, from
    // what it is told then - so the collection's own end already reads 0.
    var at_end: TableAtEpilogue = .{ .isolate = page.isolate() };
    const probe = ffi.v8_test_FullGCEpilogueProbe_New(page.isolate(), &TableAtEpilogue.onEpilogue, &at_end);
    defer ffi.v8_test_FullGCEpilogueProbe_Delete(probe);
    page.fullGC();
    try testing.expect(at_end.seen >= 1);
    try testing.expectEqual(@as(u64, 0), at_end.bytes);
    try testing.expectEqual(@as(i64, 0), try counter(page, "node_wrapper_table_bytes"));

    // And the count starts again from there.
    const dropped_at_full = page.dropped();
    try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(1000); }");
    try page.minorGC(2);
    try testing.expect(page.dropped() - dropped_at_full >= 990);
    try testing.expectEqual(@as(i64, @intCast((page.dropped() - dropped_at_full) * 8)), try counter(page, "node_wrapper_table_bytes"));
}

test "wr11: wrapper churn alone makes V8 run a full collection - the entries dropped wrappers leave are counted toward its limit" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document();");
    page.fullGC();
    const fulls = try counter(page, "full_gc_count");
    const dropped_before = page.dropped();

    // Nothing but elements made and dropped: no script object survives, the
    // anchors are freed after each young collection, the nodes by the
    // counts. What grows is V8's pointer table, 8 bytes a wrapper, swept by
    // full collections only. Reported, it reaches V8's global limit (at
    // least 8 MB above what the last collection left: 1,048,576 wrappers)
    // and V8 starts a marking cycle, which its tasks - the pump - finish.
    // Unreported, the same loop ran 8,000,000 wrappers before a full
    // collection came (gc_bench, lane wr1 b11).
    var batches: usize = 0;
    while (batches < 60 and try counter(page, "full_gc_count") == fulls) : (batches += 1) {
        try page.run("{ const make = (n) => { for (let i = 0; i < n; i++) d.createElement('div'); }; make(50000); }");
        page.pump();
        queue.drainAll();
    }
    const dropped = page.dropped() - dropped_before;
    std.debug.print("wr11 fact: V8's own full collection came after {d} dropped wrappers ({d} batches of 50,000)\n", .{ dropped, batches });
    try testing.expect(try counter(page, "full_gc_count") > fulls);
    try testing.expect(dropped <= 2_500_000);
    page.fullGC();
}

test "wr8 b8: a node whose wrapper was dropped is wrapped again with a fresh anchor, and each anchor is freed exactly once" {
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run("globalThis.d = new Document(); globalThis.root = d.createElement('section');");
    page.fullGC();
    const freed_before = try counter(page, "node_anchors_freed");
    const deferred_before = try counter(page, "node_anchor_frees_deferred");
    const dropped_before = page.dropped();
    const registered_before = try counter(page, "node_anchors_registered");

    // A node that lives on in a tree, its wrapper dropped by script at once.
    const b = try page.instance("root.appendChild(d.createElement('b'))");
    const node = dom.instance_bridge.getNodeBase(b) orelse return error.NotANode;
    const generation = SlabAllocator.generationOf(b);
    try testing.expect(page.probe(node).anchor != null);
    const count_unwrapped = dom.refcount.count(node) - 1;

    for (0..3) |round| {
        // Dropped in a scavenge: its slot empty, its reference released, its
        // anchor freed after the scavenge.
        try page.minorGC(4);
        try testing.expect(runtime.lifetime.slotOf(node).isEmpty());
        try testing.expectEqual(count_unwrapped, dom.refcount.count(node));
        try testing.expectEqual(@as(i64, 0), try counter(page, "node_anchors_dropped_waiting"));
        // Every wrapper dropped so far had its anchor freed once: never twice,
        // never refused.
        const dropped = page.dropped() - dropped_before;
        try testing.expectEqual(deferred_before, try counter(page, "node_anchor_frees_deferred"));
        try testing.expectEqual(@as(i64, @intCast(dropped)), try counter(page, "node_anchors_freed") - freed_before);
        try testing.expect(dropped >= round + 1);
        // Wrapped again: a fresh anchor in the registry, holding the node's
        // slot, the node the same one.
        try page.expectHolds("root.firstChild.localName === 'b' && root.firstChild === root.lastChild && Object.getPrototypeOf(root.firstChild) === Element.prototype");
        try testing.expectEqual(generation, SlabAllocator.generationOf(b));
        const seen = page.probe(node);
        try testing.expect(seen.has_wrapper);
        try testing.expect(seen.anchor != null);
        try testing.expectEqual(@as(?*anyopaque, @ptrCast(runtime.lifetime.slotOf(node))), seen.anchor_slot);
        try testing.expectEqual(count_unwrapped + 1, dom.refcount.count(node));
        try testing.expect(try counter(page, "node_anchors_registered") - registered_before <= 4);
    }
    // And script that holds it keeps it: its anchor stays registered.
    try page.run("globalThis.held = root.firstChild;");
    try page.minorGC(4);
    try testing.expect(!runtime.lifetime.slotOf(node).isEmpty());
    try page.expectHolds("held === root.firstChild");
    page.fullGC();
    try page.expectHolds("held === root.firstChild && held.localName === 'b'");
}
