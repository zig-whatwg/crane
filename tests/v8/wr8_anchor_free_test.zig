//! The wrapper redesign's P8, lane wr1 batch 8: a node anchor whose wrapper V8
//! dropped in a young-generation collection is freed after that collection,
//! not at the next full one.
//!
//! P8 (tests/v8/wr8_young_generation_test.zig) lets V8 drop an unmodified
//! node wrapper in a scavenge: the isolate's EmbedderRootsHandler::ResetRoot
//! empties the node's slot - V8 frees the TracedNode - and the drain releases
//! the wrapper's reference. The wrapper's NodeAnchor, 16 bytes of the agent's
//! C++ heap, and its slot in the anchors' registry waited for the next FULL
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

    /// At least `n` scavenges, nothing run after them: the drain the last
    /// one posted waits for `pump`.
    fn scavenge(self: Page, n: u32) !void {
        const entered = self.enter();
        defer self.leave(entered);
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), n);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) >= before + n);
    }

    /// At least `n` scavenges, then the agent's posted tasks (the drain a
    /// scavenge posts) and its queue.
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
    // V8 reported the full cycles to the isolate's metrics recorder: an
    // atomic pause of a live heap takes more than a microsecond, and its
    // C++ heap's share was reported with it.
    const atomic = try counter(page, "gc_atomic_us_max");
    try testing.expect(atomic > 0);
    try testing.expect(try counter(page, "gc_atomic_mark_us_max") > 0);
    try testing.expect(try counter(page, "cpp_atomic_us_max") >= 0);
    try testing.expect(try counter(page, "cpp_atomic_sweep_us_max") >= 0);
    try testing.expect(try counter(page, "cpp_atomic_weak_us_max") >= 0);
    try page.run("globalThis.kept = null;");
    page.fullGC();
}
