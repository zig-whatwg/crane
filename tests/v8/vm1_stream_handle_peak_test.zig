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

const std = @import("std");
const rounds_lib = @import("handle_rounds.zig");
const protocol = @import("engine");
const ffi = @import("v8").ffi;

const reader_of_closed_stream = "new ReadableStream({ start(c) { c.close(); } }).getReader()";

/// The streams of one burst: enough that the table grows by hundreds of
/// blocks, so a block more or less is under a percent.
const burst = 20_000;

/// The most handle bytes a kept stream with its reader may hold, and a burst
/// may add to the table per stream: 2 Globals of 32 bytes.
const kept_limit = 2 * 32;
const burst_limit = 2 * 32;

test "a kept stream with its reader holds at most two global handles" {
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

test "a burst of streams grows V8's global handle table by at most two handles a stream" {
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

    const before = ffi.v8_Isolate_GetGlobalHandleCapacityBytes(isolate);
    try rounds_lib.expectEval(page.realm, std.fmt.comptimePrint("for (let i = 0; i < {d}; i++) void " ++ reader_of_closed_stream ++ "; 'ok'", .{burst}), "ok");
    const after = ffi.v8_Isolate_GetGlobalHandleCapacityBytes(isolate);
    for (0..4) |_| try protocol.performMicrotaskCheckpoint(page.agent);
    protocol.notifyMemoryPressure(page.agent, .critical);
    protocol.notifyMemoryPressure(page.agent, .critical);

    // The table is counted in whole blocks: one block of slack.
    const block = 256 * 32;
    const grown = after - before;
    if (grown > burst * burst_limit + block) {
        std.debug.print("a burst of {d} streams grew V8's global handle table by {d} B: {d:.1} B a stream (at most {d})\n", .{ burst, grown, @as(f64, @floatFromInt(grown)) / burst, burst_limit });
        return error.BurstGrowsHandleTable;
    }
}
