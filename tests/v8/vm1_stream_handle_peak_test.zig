//! What a burst of streams costs V8's global handle table, which never
//! shrinks: V8 makes a block of 256 handle nodes when its free list is empty
//! and frees a block only with the isolate (15.7.112.43
//! src/handles/global-handles.cc, NodeSpace::Allocate and ~NodeSpace), so the
//! table's size is the most Globals that were alive at one moment. After the
//! perf suite's streams page that was 40 MB - 3,911 blocks, a million
//! Globals - held until the page's agent ended (lane wrap2 b4's malloc
//! history; lane vm1).
//!
//! A Global made and disposed inside one call goes back on the free list and
//! is the next one handed out: it does not raise the peak. What raises it is
//! what each stream KEEPS while it lives, times the streams alive at once:
//! `new ReadableStream({ start(c) { c.close(); } }).getReader()` makes three
//! platform objects - the stream, its controller, its reader - whose wrappers
//! carry traced edges, and a closed promise.
//!
//! Two figures, both read from V8 (HeapStatistics), in an agent of the
//! test's own:
//! - what one kept stream with its reader holds, in bytes of handle nodes in
//!   use after a collection (handle_rounds.handleBytesPerRound);
//! - what a burst of streams made in ONE script, none of them kept, adds to
//!   the table's capacity per stream.
//!
//! Both are BOUNDS, set from what was measured on main's adapter and on lane
//! vm1's (2026-11-17, chat2.local, this file run on both trees): a kept
//! stream with its reader holds 128 B - four handles - and a burst of 20,000
//! grew the table by 3,218,408 B - five handles a stream and 18,408 B for the
//! realm's own - on BOTH. Lane vm1 cut the Globals MADE for the statement
//! from 52 to 41 (gc_bench's creation counter; this build has none) and, as
//! that note says they would not, the transient ones it removed changed
//! neither figure. So these two tests pass on main too: they hold the table
//! where it is, and fail when a change gives a stream one more long-lived
//! handle. Lowering them is the queued follow-up (a stream's settled
//! promises and the wrapper cache's handles as traced members, Blink's
//! shape).
//!
//! The burst is 5,000 streams, not 20,000 (lane flk2, 2026-11-20): a burst
//! must run no full collection, or what it measures is the host's load. The
//! capacity V8 reports is its global handles' AND its traced handles' (V8
//! main, read 2026-11-20: src/heap/heap.cc Heap::TotalGlobalHandlesSize),
//! and a traced handle destroyed while incremental or concurrent marking
//! runs keeps its node until that collection's atomic pause
//! (src/handles/traced-handles.cc TracedHandles::Destroy: "The node will be
//! reclaimed on the next cycle") - so how many such nodes pile up is how
//! long the background markers take.
//! 20,000 streams ran two full collections and grew the table by 3,223,912,
//! 3,228,080 or 3,236,416 B on server1 (the last over the bound: 161.8 B a
//! stream, under a gate's load) and by 3,218,408 or 3,223,520 B on chat2.
//! 1,000, 2,000 and 5,000 ran none and grew 163,840, 319,488 and 802,816 B
//! in every run, at rest and beside 24 spinning shells (server1, x3 each).
//!
//! The four at rest: the wrapper cache's weak handle for each of the three
//! wrappers, which the binding's traced edges changed (wrapper_cache.zig,
//! `heldByWeakHandle`), and the reader's settled closed promise
//! (streams_settled_promise_handles_test.zig pins that one and the reader's
//! wrapper). The fifth, at the peak only, is taken to be the pending start
//! reaction's: every streams statement measured peaks one handle over what
//! it ends with for each start reaction it queues. That attribution is read
//! from the code, not measured.
//!
//! The third test is the one lane vm1's change turns from red to green: a
//! wrap makes no Global for the wrapper's prototype.

const std = @import("std");
const rounds_lib = @import("handle_rounds.zig");
const protocol = @import("engine");
const ffi = @import("v8").ffi;

const reader_of_closed_stream = "new ReadableStream({ start(c) { c.close(); } }).getReader()";

/// The streams of one burst: enough that the table grows by about a hundred
/// blocks, so a block more or less is about a percent, and few enough that no
/// full collection runs during the script (the module comment says why; the
/// test checks it).
const burst = 5_000;

/// One global handle's node in V8's table.
const handle = 32;

/// The most handle bytes a kept stream with its reader may hold: the four
/// handles measured on main's adapter and on lane vm1's (128 B on both).
const kept_limit = 4 * handle;

/// The most a burst may add to the table per stream: the five handles
/// measured on both (160 B a stream).
const burst_limit = 5 * handle;

/// What a burst may add beyond `burst_limit` a stream: the realm's own
/// handles for the script, and the table's rounding to whole blocks.
/// Measured 2,816 B for 5,000 streams (server1, every run); four blocks
/// allowed, a fifth of what one more handle a stream would add (160,000 B).
const burst_slack = 4 * 256 * handle;

/// The adapter's counter named `name` (protocol.diagnosticCounters).
fn counter(name: []const u8) !i64 {
    const counters = try protocol.diagnosticCounters(std.testing.allocator);
    defer std.testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    return error.CounterMissing;
}

test "wrapping a platform object makes no Global for its prototype or its template" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://stream-handle-peak-wrap.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm, "void " ++ reader_of_closed_stream ++ "; 'ok'", "ok");

    // The wrapper's prototype is `globalThis.<Interface>.prototype`. It was
    // fetched as a Global of its own for every wrap
    // (v8_GetGlobalPrototype, which counts its calls in every build), set
    // and disposed; it is a Local inside the one call that makes the wrapper
    // now (v8_FunctionTemplate_NewWrapper). A process-wide count: nothing
    // else in this binary wraps while the script below runs.
    const rounds = 500;
    const lookups_before = try counter("object_globals_from.GetGlobalPrototype");
    const wrappers_before = try counter("object_globals_from.ObjectTemplate_NewInstance");
    try rounds_lib.expectEval(page.realm, "for (let i = 0; i < 500; i++) void " ++ reader_of_closed_stream ++ "; 'ok'", "ok");
    const lookups = try counter("object_globals_from.GetGlobalPrototype") - lookups_before;
    const wrappers = try counter("object_globals_from.ObjectTemplate_NewInstance") - wrappers_before;
    // At least the controller and the reader are wrapped by the adapter
    // each round (the stream's own wrapper may be its constructor's `this`),
    // and each still has the interface's prototype.
    if (wrappers < 2 * rounds or lookups != 0) {
        std.debug.print("{d} wrappers made in {d} rounds (at least 2 a round expected), {d} Globals made for their prototypes (0 expected)\n", .{ wrappers, rounds, lookups });
        return error.PrototypeGlobals;
    }
    try rounds_lib.expectEval(page.realm,
        \\(() => {
        \\  let c;
        \\  const s = new ReadableStream({ start(controller) { c = controller; } });
        \\  const r = s.getReader();
        \\  return String([s instanceof ReadableStream, Object.getPrototypeOf(s) === ReadableStream.prototype,
        \\    c instanceof ReadableStreamDefaultController, Object.getPrototypeOf(c) === ReadableStreamDefaultController.prototype,
        \\    r instanceof ReadableStreamDefaultReader, Object.getPrototypeOf(r) === ReadableStreamDefaultReader.prototype]);
        \\})()
    , "true,true,true,true,true,true");
}

test "a kept stream with its reader holds at most four global handles" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://stream-handle-peak-kept.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm, "globalThis.kept = []; 'ok'", "ok");

    const kept = try rounds_lib.handleBytesPerRound(page.agent, page.realm, "kept.push(" ++ reader_of_closed_stream ++ "); 'ok'", 100);
    if (kept > kept_limit) {
        std.debug.print("a kept stream with its reader holds {d} B of global handles (at most {d})\n", .{ kept, kept_limit });
        return error.StreamKeepsGlobals;
    }
}

test "a burst of streams grows V8's global handle table by at most five handles a stream" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://stream-handle-peak-burst.test");
    defer page.end();
    const isolate = page.isolate();

    // One round first: the realm's own one-time handles, and the streams
    // prototypes.
    try rounds_lib.expectEval(page.realm, "void " ++ reader_of_closed_stream ++ "; 'ok'", "ok");
    for (0..4) |_| try protocol.performMicrotaskCheckpoint(page.agent);
    protocol.notifyMemoryPressure(page.agent, .critical);
    protocol.notifyMemoryPressure(page.agent, .critical);

    const full_collections = try counter("full_gc_count");
    const before = ffi.v8_Isolate_GetGlobalHandleCapacityBytes(isolate);
    try rounds_lib.expectEval(page.realm, "for (let i = 0; i < " ++ std.fmt.comptimePrint("{d}", .{burst}) ++ "; i++) void " ++ reader_of_closed_stream ++ "; 'ok'", "ok");
    const after = ffi.v8_Isolate_GetGlobalHandleCapacityBytes(isolate);
    // The measurement's precondition: no full collection ran during the
    // burst, so no traced handle's node waited for an atomic pause.
    const ran = try counter("full_gc_count") - full_collections;
    if (ran != 0) {
        std.debug.print("{d} full collection(s) ran during a burst of {d} streams: the table's growth is the markers' timing, not the streams' handles - make the burst smaller\n", .{ ran, burst });
        return error.BurstRanAFullCollection;
    }
    for (0..4) |_| try protocol.performMicrotaskCheckpoint(page.agent);
    protocol.notifyMemoryPressure(page.agent, .critical);
    protocol.notifyMemoryPressure(page.agent, .critical);

    const grown = after - before;
    if (grown > burst * burst_limit + burst_slack) {
        std.debug.print("a burst of {d} streams grew V8's global handle table by {d} B: {d:.1} B a stream (at most {d} a stream and {d} B over)\n", .{ burst, grown, @as(f64, @floatFromInt(grown)) / burst, burst_limit, burst_slack });
        return error.BurstGrowsHandleTable;
    }
    // And the table did grow: a burst that added nothing would mean the
    // capacity was not read (or the streams were not made).
    if (grown < burst * handle) {
        std.debug.print("a burst of {d} streams grew V8's global handle table by only {d} B\n", .{ burst, grown });
        return error.BurstNotMeasured;
    }
}
