//! Streams objects die when script can no longer reach them, not at their
//! realm's end (lane streamslife1; tmp/plans/streams-lifetime-design.md).
//!
//! Every streams wrapper used to be held strongly for its realm's life
//! (wrapper_cache.isStreamsGraphObject): the objects reached each other
//! through Zig pointers V8 cannot see, so a page that polled an API kept
//! every response body's stream, controller, reader and promise until it was
//! closed - 4 global handles a `fetch().text()`, 14 a TextDecoderStream, 25 a
//! `pipeThrough` read to its end (lane leakcheck1, 2026-11-03). Now the
//! wrappers are weak, every pointer between the objects is an edge the
//! collector traces (as Blink's core/streams classes Trace() theirs), and
//! work still pending holds what it points at until it ends.
//!
//! One test per row of leakcheck1's per-call table: each script, run 100
//! times in a Window realm of the test's own agent, leaves no global handle
//! a call once collected (handle_rounds.zig).

const std = @import("std");
const rounds_lib = @import("handle_rounds.zig");

const rounds = 100;

const Row = struct { name: []const u8, source: []const u8 };

/// Each row's handles a call, printed together, so one run names every row
/// that still keeps something.
fn expectNoneKept(rows: []const Row) !void {
    var page: rounds_lib.Page = undefined;
    try page.start("https://streams-lifetime.test");
    defer page.end();
    var kept = false;
    for (rows) |row| {
        const per_call = try rounds_lib.handlesPerRound(page.agent, page.realm, row.source, rounds);
        if (per_call != 0) {
            std.debug.print("{s}: {d} global handles kept a call\n", .{ row.name, per_call });
            kept = true;
        }
    }
    if (kept) return error.StreamsKept;
}

test "a readable stream, its reader and its iterators keep nothing once script drops them" {
    try expectNoneKept(&.{
        .{ .name = "new ReadableStream", .source = "new ReadableStream({ start(c) { c.close(); } }); 'ok'" },
        .{ .name = "a stream left open", .source = "new ReadableStream(); 'ok'" },
        .{ .name = "getReader()", .source = "new ReadableStream({ start(c) { c.close(); } }).getReader(); 'ok'" },
        .{ .name = "values()", .source = "new ReadableStream({ start(c) { c.close(); } }).values(); 'ok'" },
        .{ .name = "for await to the end", .source =
        \\(async () => { for await (const chunk of new ReadableStream({ start(c) { c.enqueue(2); c.enqueue(3); c.close(); } })) {} })();
        \\'ok'
        },
        // The controller stashed where the source's own closure reaches it:
        // a strong Global of `start` (or of the source object) kept the
        // controller, its stream and the closure itself for the realm's life.
        .{ .name = "a controller the source keeps", .source =
        \\{ let kept; new ReadableStream({ start(c) { kept = c; this.c = c; }, pull() { return kept.desiredSize; } }); }
        \\'ok'
        },
        .{ .name = "a byte stream and its BYOB reader", .source = "new ReadableStream({ type: 'bytes' }).getReader({ mode: 'byob' }); 'ok'" },
        .{ .name = "tee()", .source = "new ReadableStream({ start(c) { c.enqueue(1); c.close(); } }).tee(); 'ok'" },
        .{ .name = "a size function that closes over its stream", .source =
        \\{ let s; s = new ReadableStream({}, { size() { return s ? 1 : 1; }, highWaterMark: 2 }); }
        \\'ok'
        },
    });
}

test "a writable stream and its writer keep nothing once script drops them" {
    try expectNoneKept(&.{
        .{ .name = "new WritableStream", .source = "new WritableStream(); 'ok'" },
        .{ .name = "getWriter()", .source = "new WritableStream().getWriter(); 'ok'" },
        .{ .name = "a write to its end", .source =
        \\{ const w = new WritableStream({ write() {} }).getWriter(); w.write(1); w.close(); }
        \\'ok'
        },
        .{ .name = "a sink that keeps its controller", .source =
        \\{ let kept; new WritableStream({ start(c) { kept = c; this.c = c; } }); }
        \\'ok'
        },
    });
}

test "the transform stream family keeps nothing once script drops it" {
    try expectNoneKept(&.{
        .{ .name = "new TransformStream", .source = "new TransformStream(); 'ok'" },
        .{ .name = "a transformer that keeps its controller", .source =
        \\{ let kept; new TransformStream({ start(c) { kept = c; } }); }
        \\'ok'
        },
        .{ .name = "new TextDecoderStream", .source = "new TextDecoderStream(); 'ok'" },
        .{ .name = "new TextEncoderStream", .source = "new TextEncoderStream(); 'ok'" },
        .{ .name = "new CompressionStream", .source = "new CompressionStream('gzip'); 'ok'" },
        .{ .name = "new DecompressionStream", .source = "new DecompressionStream('gzip'); 'ok'" },
    });
}

test "a body's stream keeps nothing once script drops it: Response, Request and Blob" {
    try expectNoneKept(&.{
        .{ .name = "new Response(...).body", .source = "new Response('x').body; 'ok'" },
        .{ .name = "Response text()", .source = "new Response('x').text(); 'ok'" },
        .{ .name = "Response json()", .source = "new Response('1').json(); 'ok'" },
        .{ .name = "Response arrayBuffer()", .source = "new Response('x').arrayBuffer(); 'ok'" },
        .{ .name = "Response blob()", .source = "new Response('x').blob(); 'ok'" },
        .{ .name = "Response clone() and both read", .source =
        \\{ const r = new Response('x'); const c = r.clone(); r.text(); c.text(); }
        \\'ok'
        },
        .{ .name = "Request text()", .source = "new Request('https://streams-lifetime.test/', { method: 'POST', body: 'x' }).text(); 'ok'" },
        .{ .name = "a Response over a script stream, read", .source =
        \\new Response(new ReadableStream({ start(c) { c.enqueue(new Uint8Array([104, 105])); c.close(); } })).text();
        \\'ok'
        },
        .{ .name = "Blob stream()", .source = "new Blob(['x']).stream(); 'ok'" },
        .{ .name = "Blob stream() read to its end", .source =
        \\(async () => { const r = new Blob(['x']).stream().getReader(); while (!(await r.read()).done) {} })();
        \\'ok'
        },
    });
}

test "a pipe read to its end keeps nothing once script drops it" {
    try expectNoneKept(&.{
        .{ .name = "pipeTo to its end", .source =
        \\new ReadableStream({ start(c) { c.enqueue(1); c.close(); } }).pipeTo(new WritableStream());
        \\'ok'
        },
        .{ .name = "pipeThrough(new TextDecoderStream()) read to its end", .source =
        \\(async () => { const r = new Response('x').body.pipeThrough(new TextDecoderStream()).getReader(); while (!(await r.read()).done) {} })();
        \\'ok'
        },
        .{ .name = "pipeThrough(new TransformStream()) read to its end", .source =
        \\(async () => { const r = new ReadableStream({ start(c) { c.enqueue(1); c.close(); } }).pipeThrough(new TransformStream()).getReader(); while (!(await r.read()).done) {} })();
        \\'ok'
        },
    });
}

/// DECLARED (stage 1 of the design, section 4): a pipe whose destination is
/// never read waits forever on a TransformStream's backpressure, and the
/// pipe's own pending work holds its reader and writer - a hold on work that
/// can never finish is a root, so this graph lives until its realm ends,
/// exactly as every stream did before. Blink collects it: its pipe reactions
/// are traced from the promises they wait on, and those from their owners
/// (pipe_to_engine.cc). The next streamslife batch adds the two operations
/// that make Crane's do the same (reactToPromiseKeeping,
/// weakenPromiseCapability; design section 5), and this count becomes 0.
const unread_pipe_through_hold = 42;

test "DECLARED: an unread pipeThrough is held by its pending pipe until its realm ends" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://streams-lifetime.test");
    defer page.end();
    const per_call = try rounds_lib.handlesPerRound(page.agent, page.realm, "new Response('x').body.pipeThrough(new TextDecoderStream()); 'ok'", rounds);
    if (per_call != unread_pipe_through_hold) {
        std.debug.print("an unread pipeThrough kept {d} global handles a call (declared {d})\n", .{ per_call, unread_pipe_through_hold });
        return error.UnreadPipeHoldChanged;
    }
}
