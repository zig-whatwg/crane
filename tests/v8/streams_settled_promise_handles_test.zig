//! A streams promise (streams_js.Deferred) that is settled keeps one global
//! handle - its own hold on the promise - and a pending one its three: the
//! capability's resolver and promise as well, which settling it needs.
//!
//! Settling ends the capability's use: a settled Deferred never settles
//! again (resolve and reject return at once), so its resolver and its
//! capability's promise were two handles kept for nothing. Every one a
//! streams object keeps - a reader's [[closedPromise]], a writer's
//! [[readyPromise]] - is kept for as long as its owner lives, so the two
//! counted per settled promise per live stream (lane leakcheck1, 2026-11-03:
//! values() kept 4 handles a call, 2 of them a settled [[closedPromise]]'s
//! capability, while every streams object lived as long as its realm).
//!
//! Each round keeps what it makes alive in `kept`: what a LIVE reader or
//! writer holds is the subject here. What a dropped one leaves once collected
//! - nothing - is streams_lifetime_test.zig's.

const std = @import("std");
const rounds_lib = @import("handle_rounds.zig");

const rounds = 100;

test "a settled streams promise keeps one handle, a pending one its three" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://settled-promises.test");
    defer page.end();
    try rounds_lib.expectEval(page.realm, "globalThis.kept = []; 'ok'", "ok");

    // Counted in bytes of V8's handle tables: a v8::Global is 32 of them. The
    // wrapper cache's reference to a wrapper is one too for a reader and a
    // writer: the binding draws their edges on the wrapper (the stream, the
    // promises), V8 does not drop a changed wrapper in a young collection,
    // and the cache holds such a wrapper by a weak Global made in its record
    // (lane wrap1 b3; an unchanged wrapper's is a traced reference of 16).
    const global = try rounds_lib.handleBytes(page.realm, page.isolate());

    // A reader of a closed stream: its wrapper, and its [[closedPromise]],
    // resolved at once (ReadableStreamReaderGenericInitialize step 4.1).
    const closed_stream = try rounds_lib.handleBytesPerRound(page.agent, page.realm, "kept.push(new ReadableStream({ start(c) { c.close(); } })); 'ok'", rounds);
    const with_reader = try rounds_lib.handleBytesPerRound(page.agent, page.realm, "kept.push(new ReadableStream({ start(c) { c.close(); } }).getReader()); 'ok'", rounds);
    // A writer of a writable stream with no backpressure: its wrapper, its
    // [[readyPromise]] resolved at once and its [[closedPromise]] pending
    // (SetUpWritableStreamDefaultWriter steps 5.2 and 5.3).
    const writable = try rounds_lib.handleBytesPerRound(page.agent, page.realm, "kept.push(new WritableStream()); 'ok'", rounds);
    const with_writer = try rounds_lib.handleBytesPerRound(page.agent, page.realm, "kept.push(new WritableStream().getWriter()); 'ok'", rounds);

    const reader_kept = with_reader - closed_stream;
    const writer_kept = with_writer - writable;
    // The wrapper, and 1 handle for the settled [[closedPromise]].
    const reader_expected = global + global;
    // The wrapper, 1 handle for the settled [[readyPromise]], 3 for the
    // pending [[closedPromise]].
    const writer_expected = global + global + 3 * global;
    if (reader_kept != reader_expected or writer_kept != writer_expected) {
        std.debug.print("handle bytes kept a call: {d} by a reader of a closed stream (expected {d}), {d} by a writer (expected {d})\n", .{ reader_kept, reader_expected, writer_kept, writer_expected });
        return error.SettledPromisesKept;
    }
}
