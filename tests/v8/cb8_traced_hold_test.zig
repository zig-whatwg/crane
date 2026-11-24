//! engine.TracedHold on V8 (refcount step 8, the trace-time design approved
//! by the integrator 2026-11-23 6:53 PM ET): an owner's hold of a value it
//! keeps for script, traced at collection time from its owner - Blink's
//! TraceWrapperV8Reference. Pins the two halves of its contract:
//! - NO ROOT in a full collection: a hold nothing traces is cleared in that
//!   collection's pause - it reads empty (undefined), as a listener nobody's
//!   wrapper reaches is gone, V8's handle is freed once, and the hold's
//!   release after it is safe;
//! - a ROOT in a young-generation one: a scavenge never takes a held value,
//!   so a listener survives scavenges whatever its target's wrapper does.
//! And the value it reads is the value it was given, through the readers the
//! protocol uses on it (retainValue, sameValue).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const interfaces = @import("interfaces");

const DeferredTeardown = runtime.gc.DeferredTeardown;

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
            .agent_cluster_cross_origin_isolated = true,
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

    /// `source`'s completion, OWNED.
    fn evaluate(self: Page, source: []const u8) !engine.Owned {
        var reports: Reports = .{};
        const value = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        try testing.expectEqual(@as(usize, 0), reports.count);
        return value;
    }

    /// A traced hold of a fresh function nothing else keeps: the
    /// evaluation's own hold goes once the traced one is made.
    fn heldFunction(self: Page) !engine.TracedCallback {
        const function = try self.evaluate("(() => { const big = new Array(64).fill(7); return () => big.length; })()");
        defer function.release();
        return (engine.BorrowedCallbackFunction{ .function = function.value }).keepTraced();
    }

    fn enter(self: Page) bool {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        return entered;
    }

    fn leave(self: Page, entered: bool) void {
        if (entered) ffi.v8_Isolate_Exit(self.isolate());
    }

    fn fullGC(self: Page) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        self.queue.drainAll();
    }

    fn minorGC(self: Page, n: u32) !void {
        const entered = self.enter();
        defer self.leave(entered);
        const before = ffi.v8_Debug_MinorGCCount(self.isolate());
        ffi.v8_test_Isolate_MinorGC(self.isolate(), n);
        try testing.expect(ffi.v8_Debug_MinorGCCount(self.isolate()) >= before + n);
        while (ffi.v8_Platform_PumpMessageLoop(self.isolate())) {}
        self.queue.drainAll();
    }
};

test "a traced hold reads the value it was given, through the readers the protocol uses on it" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const function = try page.evaluate("globalThis.kept = () => 42; kept");
    defer function.release();
    const held = (engine.BorrowedCallbackFunction{ .function = function.value }).keepTraced();
    defer held.release();
    try testing.expect(!held.hold.isEmpty());
    try testing.expect(engine.sameValue(page.realm, held.hold.value(), function.value));
    const retained = try engine.retainValue(page.realm, held.hold.value());
    defer retained.release();
    try testing.expect(engine.sameValue(page.realm, retained.value, function.value));
}

/// How many holds the untraced pins make: many, so a word the collector
/// finds on the native stack (a conservative scan keeps what it names)
/// cannot decide a test.
const untraced_count = 200;

/// The slack a count of V8's handle bytes is compared with: a handful of
/// handles of the engine's own may come or go across a collection; 200
/// traced handles freed twice, or never, are far outside it.
const handle_bytes_slack = 48 * @sizeOf(usize);

fn expectHandleBytesNear(expected: usize, actual: usize) !void {
    const apart = if (actual > expected) actual - expected else expected - actual;
    if (apart > handle_bytes_slack) {
        std.debug.print("V8's handle bytes in use: expected {d} (within {d}), found {d}\n", .{ expected, handle_bytes_slack, actual });
        return error.TestUnexpectedResult;
    }
}

// V8 15.7 reports the death of a traced handle in a full collection to
// nobody: TracedHandles::ResetDeadNodes frees every node no trace reached
// and leaves the embedder's TracedReference naming it (v8-traced-handle.h:
// "The embedder needs to ensure that the handle is not accessed once the V8
// object has been reclaimed"). The adapter records it itself: a hold's cell
// is stamped where it is traced, and the cells no trace stamped are written
// empty in the same pause (v8_wrapper.cpp, "engine.TracedHold"). Three pins,
// each red on the first trace-time build (e1c26d48d), whose holds were left
// naming freed nodes: they read non-empty, their release freed a V8 node a
// second time, and the next holds were given nodes handed out twice.

test "a traced hold nobody traces reads empty after a full collection" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    var holds: [untraced_count]engine.TracedCallback = undefined;
    for (&holds) |*held| held.* = try page.heldFunction();
    defer for (holds) |held| held.release();
    for (holds) |held| try testing.expect(!held.hold.isEmpty());
    page.fullGC();
    var cleared: usize = 0;
    for (holds) |held| {
        if (!held.hold.isEmpty()) continue;
        cleared += 1;
        try testing.expect(held.hold.value().isUndefined());
    }
    std.debug.print("untraced holds that read empty after a full collection: {d} of {d}\n", .{ cleared, holds.len });
    try testing.expectEqual(holds.len, cleared);
}

test "an untraced hold's V8 handle is freed once: by the collection, not again by the hold's release" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    // The page's own handles settle first: one hold made and ended, collected.
    (try page.heldFunction()).release();
    page.fullGC();
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    var holds: [untraced_count]engine.TracedCallback = undefined;
    for (&holds) |*held| held.* = try page.heldFunction();
    const made = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    try testing.expect(made >= before + untraced_count * @sizeOf(usize));
    // The collection frees every hold's node: nothing traced one.
    page.fullGC();
    const collected = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    // The releases free nothing of V8's a second time.
    for (holds) |held| held.release();
    const released = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    page.fullGC();
    const settled = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    std.debug.print("V8's handle bytes in use: before {d}, {d} holds made {d}, collected {d}, released {d}, after one more collection {d}\n", .{ before, holds.len, made, collected, released, settled });
    try expectHandleBytesNear(before, collected);
    try expectHandleBytesNear(before, released);
    try expectHandleBytesNear(before, settled);
}

test "a hold released after the collection that took its value is safe: the next holds read their own values" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    var holds: [untraced_count]engine.TracedCallback = undefined;
    for (&holds) |*held| held.* = try page.heldFunction();
    page.fullGC();
    for (holds) |held| held.release();
    // New holds, each of a function the test keeps: every one reads its own,
    // now and after scavenges, and a second round does after another
    // collection took the first round's.
    for (0..2) |_| {
        var functions: [untraced_count]engine.Owned = undefined;
        var again: [untraced_count]engine.TracedCallback = undefined;
        for (&functions, &again) |*function, *held| {
            function.* = try page.evaluate("(() => { const big = new Array(64).fill(7); return () => big.length; })()");
            held.* = (engine.BorrowedCallbackFunction{ .function = function.value }).keepTraced();
        }
        defer for (functions) |function| function.release();
        for (functions, again) |function, held| {
            try testing.expect(!held.hold.isEmpty());
            try testing.expect(engine.sameValue(page.realm, held.hold.value(), function.value));
        }
        try page.minorGC(2);
        for (functions, again) |function, held| {
            try testing.expect(!held.hold.isEmpty());
            try testing.expect(engine.sameValue(page.realm, held.hold.value(), function.value));
        }
        // Nothing traces them: the collection takes each hold, though the
        // test still keeps the function, and the release after it is safe.
        page.fullGC();
        for (again) |held| {
            try testing.expect(held.hold.isEmpty());
            held.release();
        }
    }
}

const SlabStats = struct {
    live: u64 = 0,
    chunks: u64 = 0,
    swept: u64 = 0,

    fn of(page: Page) SlabStats {
        var stats: SlabStats = .{};
        ffi.v8_test_TracedHolds_Stats(page.isolate(), &stats.live, &stats.chunks, &stats.swept);
        return stats;
    }
};

test "the collection's pause counts the holds it took, and a hold it took still occupies its cell until released" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const start = SlabStats.of(page);
    var holds: [untraced_count]engine.TracedCallback = undefined;
    for (&holds) |*held| held.* = try page.heldFunction();
    try testing.expectEqual(start.live + untraced_count, SlabStats.of(page).live);
    page.fullGC();
    const collected = SlabStats.of(page);
    try testing.expectEqual(start.swept + untraced_count, collected.swept);
    try testing.expectEqual(start.live + untraced_count, collected.live);
    for (holds) |held| held.release();
    try testing.expectEqual(start.live, SlabStats.of(page).live);
    // Nothing is left to take.
    page.fullGC();
    try testing.expectEqual(collected.swept, SlabStats.of(page).swept);
}

test "the agent's hold slab grows by chunks and gives the spare ones back" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const function = try page.evaluate("globalThis.kept = () => 42; kept");
    defer function.release();
    const cells: usize = ffi.v8_test_TracedHolds_ChunkCells();
    const count = 2 * cells + 7;
    const holds = try testing.allocator.alloc(engine.TracedCallback, count);
    defer testing.allocator.free(holds);
    const start = SlabStats.of(page);
    for (holds) |*held| held.* = (engine.BorrowedCallbackFunction{ .function = function.value }).keepTraced();
    const full = SlabStats.of(page);
    try testing.expectEqual(start.live + count, full.live);
    try testing.expect(full.chunks >= 3);
    // Every hold reads the function, whichever chunk its cell is in.
    for (holds) |held| try testing.expect(engine.sameValue(page.realm, held.hold.value(), function.value));
    // The middle chunk's holds end first, then the rest: one chunk with a
    // free cell is kept, the others go back to the host.
    for (holds[cells .. 2 * cells]) |held| held.release();
    for (holds[0..cells]) |held| held.release();
    for (holds[2 * cells ..]) |held| held.release();
    const empty = SlabStats.of(page);
    try testing.expectEqual(start.live, empty.live);
    try testing.expect(empty.chunks <= 1 + start.chunks);
    // And the slab is used again.
    const again = (engine.BorrowedCallbackFunction{ .function = function.value }).keepTraced();
    defer again.release();
    try testing.expect(engine.sameValue(page.realm, again.hold.value(), function.value));
}

test "a hold its owner releases after the agent's end reads empty and is released without the engine" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    var holds: [untraced_count]engine.TracedCallback = undefined;
    {
        const page = try Page.open(&queue);
        defer page.close();
        const function = try page.evaluate("globalThis.kept = () => 42; kept");
        defer function.release();
        for (&holds) |*held| held.* = (engine.BorrowedCallbackFunction{ .function = function.value }).keepTraced();
        for (holds) |held| try testing.expect(!held.hold.isEmpty());
        // Some end with the agent alive, the rest outlive it.
        for (holds[0 .. untraced_count / 2]) |held| held.release();
    }
    // The agent and its isolate are gone: the slab outlives them for these.
    for (holds[untraced_count / 2 ..]) |held| {
        try testing.expect(held.hold.isEmpty());
        try testing.expect(held.hold.value().isUndefined());
        held.release();
    }
}

// A node that keeps values for script (a listener, a registered observer) must
// keep its wrapper through young-generation collections: the walk that traces
// those values enters held subtrees only, and a node whose unmodified wrapper
// a scavenge dropped is not held. The first trace-time build (e1c26d48d) marked
// such a node's wrapper with a private property - and, for a node with no
// wrapper yet, kept the mark waiting in a strong v8::Global until the node was
// wrapped: 32 bytes of V8's handles, a map entry and a key for every node
// REMOVED under a subtree MutationObserver (DOM "remove" step 15 gives each a
// transient registered observer). Now the node's wrapper slot is simply not
// droppable (engine.keepNodeWrapperInYoungCollections), decided where the node
// is marked if it has a wrapper and where it is wrapped if not: nothing is
// made for an unwrapped node, and nothing is written on a wrapper.

const subtree_observer =
    \\globalThis.t = {};
    \\t.doc = new Document().implementation.createHTMLDocument("");
    \\t.p = t.doc.body.appendChild(t.doc.createElement("p"));
    \\t.observer = new MutationObserver(() => {});
    \\t.observer.observe(t.doc.body, { childList: true, subtree: true });
    \\0
;

test "a node removed under a subtree observer costs no V8 handle: nothing waits for a wrapper it may never get" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    (try page.evaluate(subtree_observer)).release();
    // Whatever the first removals make once (templates, the record queue).
    (try page.evaluate("for (let i = 0; i < 8; i++) t.p.textContent = 'w' + i; 0")).release();
    const removals = 2000;
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    // Each pass removes a Text node no script ever saw; the observer's queue
    // keeps it (its record's removedNodes), unwrapped.
    (try page.evaluate("for (let i = 0; i < 2000; i++) t.p.textContent = 'x' + i; 0")).release();
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    const per_node = @as(f64, @floatFromInt(after -| before)) / @as(f64, removals);
    std.debug.print("V8 handle bytes per node removed under a subtree observer: {d:.2} (before {d}, after {d})\n", .{ per_node, before, after });
    try testing.expect(per_node < 0.5);
}

test "a listener's node keeps its wrapper through young collections, and its listeners through a full one" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    (try page.evaluate(subtree_observer)).release();
    // The control: 200 elements script let go of, nothing kept on them - a
    // scavenge drops their unmodified wrappers.
    try page.minorGC(2);
    const control_before = ffi.v8_test_NodeWrappers_Dropped(page.isolate());
    (try page.evaluate("(() => { for (let i = 0; i < 200; i++) t.doc.body.appendChild(t.doc.createElement('i')); })(); 0")).release();
    try page.minorGC(4);
    const control = ffi.v8_test_NodeWrappers_Dropped(page.isolate()) - control_before;
    // 200 elements with a listener each, script holding none of them.
    (try page.evaluate(
        \\t.fired = 0;
        \\(() => { for (let i = 0; i < 200; i++) t.doc.body.appendChild(t.doc.createElement('b')).addEventListener('x', () => { t.fired++; }); })();
        \\0
    )).release();
    const before = ffi.v8_test_NodeWrappers_Dropped(page.isolate());
    try page.minorGC(4);
    const dropped = ffi.v8_test_NodeWrappers_Dropped(page.isolate()) - before;
    std.debug.print("node wrappers young collections dropped: {d} of 200 plain elements, {d} of 200 with a listener\n", .{ control, dropped });
    try testing.expect(control >= 150);
    try testing.expect(dropped <= 8);
    // And the walk reaches every one from the document script holds.
    page.fullGC();
    (try page.evaluate("for (const b of t.doc.body.querySelectorAll('b')) b.dispatchEvent(new Event('x')); 0")).release();
    var reports: Reports = .{};
    const fired = try engine.evaluateClassicScriptToString(page.realm, .{ .utf8 = "String(t.fired)" }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(fired);
    try testing.expectEqual(@as(usize, 0), reports.count);
    try testing.expectEqualStrings("200", fired);
}

test "a node marked before it had a wrapper gets one young collections keep" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    (try page.evaluate(subtree_observer)).release();
    // 200 elements the parser made (no wrapper), removed under the subtree
    // observer: each lists a transient registered observer, unwrapped. The
    // record keeps them; then script sees each once and lets go.
    (try page.evaluate(
        \\t.p.innerHTML = "<u></u>".repeat(200);
        \\t.p.textContent = "";
        \\t.records = t.observer.takeRecords();
        \\0
    )).release();
    try page.minorGC(2);
    const before = ffi.v8_test_NodeWrappers_Dropped(page.isolate());
    (try page.evaluate("(() => { let n = 0; for (const record of t.records) for (const node of record.removedNodes) if (node.nodeName === 'U') n++; return n; })()")).release();
    try page.minorGC(4);
    const dropped = ffi.v8_test_NodeWrappers_Dropped(page.isolate()) - before;
    std.debug.print("wrappers of 200 nodes marked while unwrapped that young collections dropped: {d}\n", .{dropped});
    try testing.expect(dropped <= 8);
}

test "a held value survives scavenges: a traced hold is a root in a young-generation collection" {
    var queue: DeferredTeardown = .init(std.heap.c_allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const held = try page.heldFunction();
    defer held.release();
    try page.minorGC(4);
    try testing.expect(!held.hold.isEmpty());
    // Still the function: it runs.
    const retained = try engine.retainValue(page.realm, held.hold.value());
    defer retained.release();
    try testing.expect(retained.value == .handle);
}
