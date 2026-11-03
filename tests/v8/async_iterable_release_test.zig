//! The async iterable binding (interface.zig asyncIteratorCallback) releases
//! the iterator the impl hands it, once the return value has it.
//!
//! `stream.values()` and `for await (... of stream)` reach the impl's
//! call_values, which gives the binding an owned Global of the new WebIDL
//! asynchronous iterator object. The binding set it as the call's return
//! value and kept it: a strong root, so the iterator - its state, its
//! weak-armed record (protocol_async_iterator.zig), its reader and its stream
//! - lived to the agent's end, one per `for await`. Found by instances B2's
//! measurement (agents_concurrent_engine_state_test.zig): the live weak
//! callback records grew by one per round, in every agent.
//!
//! Measured in the agent's own isolate (handle_rounds.zig): V8's used global
//! handle bytes, which every Global of the agent counts in, whoever made it.
//!
//! What a round keeps, read by lane leakcheck1 (2026-11-03) with that
//! measure, the adapter's counters and a heap snapshot's "(Global handles)"
//! root:
//! - a classic script evaluation with its microtask checkpoints: nothing (the
//!   first test);
//! - an iterator: nothing - the object is collected, its weak record with it
//!   (the second test);
//! - the stream it iterates, and the stream's reader: a DECLARED hold, below.
//!   A streams-graph object's wrapper is held strongly for its realm's life
//!   (wrapper_cache.isStreamsGraphObject, runtime/streams_graph.zig: Zig
//!   pointers V8 cannot trace join a stream, its controller and its reader),
//!   so every stream a page makes keeps its handles until the page's realm
//!   ends - which gives back every one (the third test, the bound). Ending
//!   that hold is the streams lifetime design: refcount design D3, phase 2
//!   (tmp/plans/refcount-design.md) - traced edges between the streams
//!   objects, as Blink's core/streams classes Trace() them.

const std = @import("std");
const rounds_lib = @import("handle_rounds.zig");
const protocol = @import("engine");
const ffi = @import("v8").ffi;

/// The realm hold of a ReadableStream: its wrapper and its controller's.
const stream_hold = 2;
/// The realm hold of a reader: its wrapper, and its [[closedPromise]] -
/// settled, so the promise's own hold alone
/// (streams_settled_promise_handles_test.zig).
const reader_hold = 2;

const rounds = 100;

test "a classic script evaluation and its microtask checkpoints keep no global handle" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://evaluations.test");
    defer page.end();

    const scripts = [_]struct { name: []const u8, source: []const u8 }{
        .{ .name = "a value", .source = "'ok'" },
        .{ .name = "an object", .source = "({}); 'ok'" },
        .{ .name = "a promise reaction", .source = "Promise.resolve().then(() => {}); 'ok'" },
        .{ .name = "an async function", .source = "(async () => { await null; })(); 'ok'" },
        .{ .name = "a sync iterator", .source = "new URLSearchParams('a=1').entries().next(); 'ok'" },
    };
    var kept = false;
    for (scripts) |script| {
        const left = try rounds_lib.handlesLeftBy(page.agent, page.realm, script.source, rounds);
        if (left >= rounds / 2) {
            std.debug.print("global handles left by {s}: {d} over {d} rounds\n", .{ script.name, left, rounds });
            kept = true;
        }
    }
    if (kept) return error.EvaluationsKept;
}

test "an async iterator script drops is collected: values() and for await keep nothing per call beyond their stream's declared hold" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://iterators.test");
    defer page.end();
    const agent = page.agent;
    const realm = page.realm;

    // The stream alone keeps exactly its declared hold.
    const stream_kept = try rounds_lib.handlesPerRound(agent, realm, "new ReadableStream({ start(c) { c.close(); } }); 'ok'", rounds);
    // An iterator made and dropped at once: its reader stays the stream's.
    const values_kept = try rounds_lib.handlesPerRound(agent, realm, "new ReadableStream({ start(c) { c.close(); } }).values(); 'ok'", rounds);
    // A for await to the end of the stream (its iterator from
    // @@asyncIterator): the stream drained and closed, its source algorithms
    // cleared, its reader released - and still held, as the stream is.
    const for_await_kept = try rounds_lib.handlesPerRound(agent, realm,
        \\globalThis.total = 0;
        \\(async () => { for await (const chunk of new ReadableStream({ start(c) { c.enqueue(2); c.enqueue(3); c.close(); } })) total += chunk; })();
        \\'ok'
    , rounds);
    try rounds_lib.expectEval(realm, "String(total)", "5");

    const values_own = values_kept - (stream_hold + reader_hold);
    const for_await_own = for_await_kept - (stream_hold + reader_hold);
    if (stream_kept != stream_hold or values_own != 0 or for_await_own != 0) {
        std.debug.print("handles kept a call: {d} by a stream (declared {d}); {d} by values() and {d} by for await (declared {d} each: the iterators' own {d} and {d})\n", .{ stream_kept, stream_hold, values_kept, for_await_kept, stream_hold + reader_hold, values_own, for_await_own });
        return error.IteratorsKept;
    }
}

test "a realm's end gives back every global handle its streams and iterators kept" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://iterators.test");
    defer page.end();
    const isolate = page.isolate();
    const handle = try rounds_lib.handleBytes(page.realm, isolate);

    protocol.notifyMemoryPressure(page.agent, .critical);
    const start_bytes: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    const second = try page.newRealm("https://iterators-second.test");
    const kept = try rounds_lib.handlesLeftBy(page.agent, second, "new ReadableStream({ start(c) { c.close(); } }).values(); 'ok'", rounds);
    protocol.destroyWindowRealm(second, .global_detached);
    for (0..4) |_| try protocol.performMicrotaskCheckpoint(page.agent);
    protocol.notifyMemoryPressure(page.agent, .critical);
    protocol.notifyMemoryPressure(page.agent, .critical);
    const end_bytes: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    const left = @divTrunc(end_bytes - start_bytes, handle);
    if (left != 0) {
        std.debug.print("the realm's {d} rounds kept {d} handles while it lived; {d} left after its end\n", .{ rounds, kept, left });
        return error.RealmEndKept;
    }
}
