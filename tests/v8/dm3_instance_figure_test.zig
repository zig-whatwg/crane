//! What V8 is told of the instances behind non-node wrappers: the figure of the LIVE ones (lane dm3; lane dm1's
//! design, tmp/plans/dom-memory-figure-design.md 3.6).
//!
//! A non-node platform object's wrapper is 16 B of V8's heap and keeps a Zig instance V8 cannot see. Until this
//! batch the adapter told V8 an account of ALLOCATION (lane wrap1 b3): the bytes put behind wrappers since the last
//! full collection began, taken back whole in the next one's prologue. Three things were wrong with what V8 then
//! believed, and each test here is one of them:
//!
//! 1. What survives a full collection was not counted again: a page that keeps 6,000 URLSearchParams read as
//!    keeping none, and V8 set its next limit as if they did not exist. Both browsers give their collector what
//!    the survivors keep - Blink's objects are on V8's C++ heap, whose marked bytes V8 reads after marking (V8
//!    15.7.112.43 src/heap/cppgc-js/cpp-heap.cc:1016); a full collection of JavaScriptCore zeroes its extra-memory
//!    sum and each visited wrapper adds what it keeps (WebKit 621b33b3b71 Source/JavaScriptCore/heap/Heap.cpp:
//!    1811-1817, :2254-2270).
//! 2. What a full collection found dead left V8's count in its PROLOGUE - for an incremental collection that is
//!    when marking starts - not where the dead are known. The figure falls now at the end of marking, in the
//!    collection's atomic pause, before V8 computes its next limits and before any finalizer runs.
//! 3. A wrapper a young collection dropped stayed in the account until the next full collection, so a loop of
//!    short-lived objects asked V8 for full collections it did not need. It leaves the figure with the drop.
//!
//! The figure is read through the adapter's own reads (v8_Debug_WrappedInstanceBytes: the figure, and what V8
//! holds of it) and V8's total (v8_Isolate_GetExternalMemory). The collections are V8's own. The file shares
//! tests/v8's process: it starts the engine as any file may and makes its own agent per test.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;
const wrapper_cache = @import("v8").wrapper_cache_mod;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

/// V8's step: the adapter tells V8 once the figure moved this far from what V8 holds.
const step: u64 = 128 * 1024;

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        test_process.start();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &test_process.no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://dm3.test",
            .global_this = .new_window_proxy,
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        // The adapter's Agent is the isolate (protocol.zig isolateOf).
        return @ptrCast(@alignCast(self.agent));
    }

    fn enter(self: Page) bool {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        return entered;
    }

    fn leave(self: Page, entered: bool) void {
        if (entered) ffi.v8_Isolate_Exit(self.isolate());
    }

    fn evalOwned(self: Page, source: []const u8) !protocol.Owned {
        var reports: Reports = .{};
        const got = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        try testing.expectEqual(@as(usize, 0), reports.count);
        return got;
    }

    fn run(self: Page, source: []const u8) !void {
        (try self.evalOwned(source)).release();
    }

    /// Two requested full collections (the second takes what the first's finalizers let go), each followed by
    /// the agent's safe point.
    fn fullGC(self: Page) void {
        const entered = self.enter();
        defer self.leave(entered);
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
    }

    /// The agent's safe point: its posted tasks, then its queued finalizers and reports.
    fn safePoint(self: Page) void {
        const entered = self.enter();
        defer self.leave(entered);
        while (ffi.v8_Platform_PumpMessageLoop(self.isolate())) {}
        _ = ffi.v8_Isolate_RunQueuedFinalizers(self.isolate());
    }

    fn fullCollections(self: Page) u64 {
        var count: u64 = 0;
        var max_us: u64 = 0;
        var p95_us: u64 = 0;
        ffi.v8_Debug_FullGCPauses(self.isolate(), &count, &max_us, &p95_us);
        return count;
    }

    /// The figure: what the instances behind the agent's live non-node wrappers hold.
    fn figure(self: Page) u64 {
        return ffi.v8_Debug_WrappedInstanceBytes(self.isolate(), false);
    }

    /// What V8 holds of the figure now.
    fn told(self: Page) u64 {
        return ffi.v8_Debug_WrappedInstanceBytes(self.isolate(), true);
    }

    /// V8's own total of external memory: everything every accounter of the agent told it.
    fn v8External(self: Page) u64 {
        return ffi.v8_Isolate_GetExternalMemory(self.isolate());
    }

    /// The agent's records whose wrapper a collection took and whose finalizer has not run.
    fn pending(self: Page) usize {
        const entered = self.enter();
        defer self.leave(entered);
        return wrapper_cache.livePendingCount();
    }

    /// What one object made by `make` puts into the figure.
    fn heldBy(self: Page, make: []const u8) !u64 {
        var source: [200]u8 = undefined;
        const one = try self.evalOwned(try std.fmt.bufPrint(&source, "globalThis.one = {s}; one", .{make}));
        defer one.release();
        const instance = protocol.convertToPlatformObject(self.realm, one.value) orelse return error.NoInstance;
        const held = wrapper_cache.instanceHeldBytes(instance);
        try self.run("globalThis.one = null; 0");
        return held;
    }
};

/// An object whose wrapper its cache holds by a traced reference (V8 may drop it in a young collection), and one
/// it holds by a weak handle (an Event is born with an own property).
const traced_shape = "new URLSearchParams('a=b')";
const weak_shape = "new Event('x')";

test "what the instances behind kept wrappers hold stays in what V8 is told after a full collection" {
    const page = try Page.open();
    defer page.close();
    const n = 6000;
    const per_pair = try page.heldBy(traced_shape) + try page.heldBy(weak_shape);
    // The shapes' sizes are whole units of the record's byte, so the figure counts them exactly.
    try testing.expect(per_pair >= 2 * 64 and per_pair <= 2 * 2040 and per_pair % 8 == 0);

    page.fullGC();
    const base = page.figure();
    var source: [240]u8 = undefined;
    try page.run(try std.fmt.bufPrint(&source, "globalThis.keep = []; for (let i = 0; i < {d}; i++) keep.push({s}, {s}); 0", .{ n, traced_shape, weak_shape }));
    // Every pair is in the figure as it is made...
    try testing.expect(page.figure() >= base + n * per_pair);
    page.fullGC();
    // ...and after full collections that kept them all: the figure is what live wrappers keep.
    const kept = page.figure();
    std.debug.print("{d} kept pairs of {d} B: the figure is {d} B over its base after full collections, V8 holds {d} B of {d}\n", .{ n, per_pair, kept -| base, page.told(), kept });
    try testing.expect(kept >= base + n * per_pair);
    try testing.expect(kept < base + n * per_pair + 64 * 1024);
    // V8 holds it, to within the report's step, and it is in V8's own total.
    try testing.expect(page.told() + step > kept and page.told() < kept + step);
    try testing.expect(page.v8External() >= page.told());

    // Dropped, they leave it.
    try page.run("globalThis.keep = null; 0");
    page.fullGC();
    try testing.expect(page.figure() < base + 64 * 1024);
    try testing.expect(page.told() < base + 64 * 1024 + step);
}

test "what a full collection finds dead leaves V8's count inside the collection, before any finalizer runs" {
    const page = try Page.open();
    defer page.close();
    const n = 6000;
    const per_pair = try page.heldBy(traced_shape) + try page.heldBy(weak_shape);

    page.fullGC();
    var source: [240]u8 = undefined;
    try page.run(try std.fmt.bufPrint(&source, "globalThis.keep = []; for (let i = 0; i < {d}; i++) keep.push({s}, {s}); 0", .{ n, traced_shape, weak_shape }));
    page.fullGC();
    const told_kept = page.told();
    const v8_kept = page.v8External();
    try testing.expect(told_kept + step > n * per_pair);

    try page.run("globalThis.keep = null; 0");
    const pending_before = page.pending();
    {
        const entered = page.enter();
        defer page.leave(entered);
        // A full collection with no safe point at its end: what it found dead waits for its finalizer.
        ffi.v8_test_Isolate_CollectWithoutDrain(page.isolate());
    }
    // Nothing was finalized: every dead pair's records wait...
    const pending_after = page.pending();
    try testing.expect(pending_after >= pending_before + 2 * n);
    // ...and V8's count has fallen by what their instances hold already. The traced records' share left with one
    // decrease in the collection's atomic pause; so did the weak-handle records', whose anchors the marking did
    // not reach.
    const told_after = page.told();
    const v8_after = page.v8External();
    std.debug.print("{d} dead pairs of {d} B, before any finalizer: V8 held {d} B, holds {d} B; its own total {d} -> {d}\n", .{ n, per_pair, told_kept, told_after, v8_kept, v8_after });
    try testing.expect(told_kept - told_after + step >= n * per_pair);
    try testing.expect(v8_kept - v8_after + step >= n * per_pair);

    // The finalizers then free the instances and change nothing V8 was told.
    page.safePoint();
    try testing.expect(page.pending() <= pending_before);
    try testing.expect(page.told() <= told_after);
}

test "a wrapper a young collection drops leaves the figure without a full collection" {
    const page = try Page.open();
    defer page.close();
    const n = 20000;
    const held = try page.heldBy(traced_shape);

    var attempt: usize = 0;
    while (attempt < 4) : (attempt += 1) {
        page.fullGC();
        const base = page.figure();
        const full_before = page.fullCollections();
        var source: [200]u8 = undefined;
        // Nothing keeps them: V8 drops each wrapper in a young collection (an unmodified API object).
        try page.run(try std.fmt.bufPrint(&source, "for (let i = 0; i < {d}; i++) void {s}; 0", .{ n, traced_shape }));
        {
            const entered = page.enter();
            defer page.leave(entered);
            ffi.v8_test_Isolate_MinorGC(page.isolate(), 2);
        }
        page.safePoint();
        // A full collection V8 chose to run meanwhile would have taken them all: read again.
        if (page.fullCollections() != full_before) continue;
        const left = page.figure() -| base;
        std.debug.print("{d} dropped URLSearchParams of {d} B, no full collection: {d} B of {d} are still in the figure, V8 holds {d} B\n", .{ n, held, left, n * held, page.told() });
        // All but the last few (made after the last young collection of the loop began) have left.
        try testing.expect(left < n * held / 10);
        // And V8 was told: what it holds is within a step of the figure.
        try testing.expect(page.told() < page.figure() + step);
        return;
    }
    std.debug.print("a full collection ran in each of {d} attempts: nothing was read\n", .{attempt});
    return error.TestInconclusive;
}

test "a record takes out of the figure exactly what it put in" {
    // The figure is a sum that stays true only if every record's share leaves it once, and whole. The record
    // keeps what it added in a byte of its own, in units of 8 B (wrapper_cache.zig `Cell.Stamp.held`), and
    // nothing of the instance is read when it leaves - the instance may be freed by then, or its slot another
    // object's. So after any mix of objects is made, dropped and collected, the figure is back where it was: to
    // the byte.
    const page = try Page.open();
    defer page.close();
    const held = try page.heldBy(traced_shape);
    // One unit is 8 B and these shapes' shares are whole units: counted exactly.
    try testing.expectEqual(held, wrapper_cache.countedBytes(held));
    // The record's byte saturates: an instance that holds more than 2,040 B is counted as 2,040 (a floor).
    try testing.expectEqual(@as(usize, 2040), wrapper_cache.countedBytes(5000));
    try testing.expectEqual(@as(usize, 2040), wrapper_cache.countedBytes(2040));
    try testing.expectEqual(@as(usize, 8), wrapper_cache.countedBytes(1));
    try testing.expectEqual(@as(usize, 0), wrapper_cache.countedBytes(0));

    // Warm: every object the script itself makes once (the interfaces' prototypes are not counted, their
    // wrappers' records are).
    const mix = "for (let i = 0; i < 1500; i++) { const e = new Event('x'); const p = new URLSearchParams('a=b'); const h = new Headers(); " ++
        "const q = new URLSearchParams('c=d'); q.mine = i; const c = new AbortController(); void c.signal; if (i % 3 == 0) (globalThis.some ??= []).push(e, p, h, q, c); } 0";
    try page.run(mix);
    try page.run("globalThis.some = null; 0");
    page.fullGC();
    page.fullGC();
    const base = page.figure();
    var round: usize = 0;
    while (round < 3) : (round += 1) {
        try page.run(mix);
        try testing.expect(page.figure() > base + 1500 * held);
        try page.run("globalThis.some = null; 0");
        page.fullGC();
        page.fullGC();
        try testing.expectEqual(base, page.figure());
        // And V8 holds no more than the figure plus a step.
        try testing.expect(page.told() < base + step);
    }
}
