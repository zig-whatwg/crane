//! A streams object that script no longer reaches is collected - but never
//! while work still pending will run with a pointer to it (lane
//! streamslife1; tmp/plans/streams-lifetime-design.md 3.4).
//!
//! The classic bug of moving streams wrappers from strong to weak: a reaction,
//! a read request, a pipe or an iterator holds a Zig pointer V8 cannot see,
//! the collector takes the object in between, and the work later runs on a
//! freed instance. Each test leaves one kind of pending work with nothing
//! else reaching its objects, collects twice (critical memory pressure, which
//! also runs V8's second-pass teardowns), then lets the work finish and
//! checks what script sees. Every realm allocates through the testing
//! allocator's leak checks only where the page does; a use-after-free shows
//! as a crash or a wrong `out`.

const std = @import("std");
const testing = std.testing;
const rounds_lib = @import("handle_rounds.zig");
const protocol = @import("engine");

/// Collect as hard as V8 can, twice, with microtask checkpoints between -
/// what a long page's idle time does to everything unreachable.
fn collect(page: *rounds_lib.Page) !void {
    for (0..2) |_| {
        protocol.notifyMemoryPressure(page.agent, .critical);
        try protocol.performMicrotaskCheckpoint(page.agent);
    }
}

/// Run `source` in the page's realm, then drain its microtasks.
fn run(page: *rounds_lib.Page, source: []const u8) !void {
    try rounds_lib.expectEval(page.realm, source, "ok");
    for (0..4) |_| try protocol.performMicrotaskCheckpoint(page.agent);
}

fn expectOut(page: *rounds_lib.Page, expected: []const u8) !void {
    try rounds_lib.expectEval(page.realm, "JSON.stringify(out)", expected);
}

fn startPage(page: *rounds_lib.Page) !void {
    try page.start("https://streams-midflight.test");
    errdefer page.end();
    try run(page, "globalThis.out = []; 'ok'");
}

test "a pending start keeps its stream: the start reaction holds the controller" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    // Script keeps only start()'s resolver, which reaches neither the stream
    // nor its controller; the read's continuation reaches only `out`.
    try run(&page,
        \\new ReadableStream({
        \\  start() { return new Promise((r) => { globalThis.go = r; }); },
        \\  pull(c) { c.enqueue('pulled'); c.close(); },
        \\}).getReader().read().then((v) => out.push(v.value));
        \\'ok'
    );
    try collect(&page);
    try run(&page, "go(); 'ok'");
    try collect(&page);
    try expectOut(&page, "[\"pulled\"]");
}

test "a pending pull keeps its stream: the pull reaction holds the controller" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    // The first pull answers the first read and stays pending; the second
    // read asks for another pull (pullAgain), which runs once `go` settles
    // the first - with nothing but that pending pull reaching the stream.
    try run(&page,
        \\globalThis.n = 0;
        \\{
        \\  const reader = new ReadableStream({
        \\    pull(c) { c.enqueue(n++); return new Promise((r) => { globalThis.go = r; }); },
        \\  }, { highWaterMark: 0 }).getReader();
        \\  reader.read().then((v) => out.push(v.value));
        \\  reader.read().then((v) => out.push(v.value));
        \\}
        \\'ok'
    );
    try collect(&page);
    try run(&page, "go(); 'ok'");
    try collect(&page);
    try expectOut(&page, "[0,1]");
}

test "a write in flight keeps its stream: the sink write reaction holds the controller" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    try run(&page,
        \\{
        \\  const writer = new WritableStream({
        \\    write(chunk) { out.push(chunk); return new Promise((r) => { globalThis.go = r; }); },
        \\    close() { out.push('closed'); },
        \\  }).getWriter();
        \\  writer.write('a');
        \\  writer.write('b');
        \\  writer.close();
        \\}
        \\'ok'
    );
    try collect(&page);
    try run(&page, "go(); 'ok'");
    try collect(&page);
    try run(&page, "go(); 'ok'");
    try collect(&page);
    try expectOut(&page, "[\"a\",\"b\",\"closed\"]");
}

test "a pipe whose source and destination script dropped runs to its end" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    // The source is driven from outside (script keeps its controller); the
    // destination is reached by nothing but the pipe.
    try run(&page,
        \\new ReadableStream({ start(c) { globalThis.source = c; } })
        \\  .pipeTo(new WritableStream({ write(chunk) { out.push(chunk); }, close() { out.push('closed'); } }));
        \\'ok'
    );
    try collect(&page);
    try run(&page, "source.enqueue('a'); 'ok'");
    try collect(&page);
    try run(&page, "source.enqueue('b'); source.close(); 'ok'");
    try collect(&page);
    try expectOut(&page, "[\"a\",\"b\",\"closed\"]");
}

test "a pipe driven by its destination runs to its end" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    // Everything is queued in the source already; each write waits for `go`.
    try run(&page,
        \\new ReadableStream({ start(c) { c.enqueue('a'); c.enqueue('b'); c.close(); } })
        \\  .pipeTo(new WritableStream({ write(chunk) { out.push(chunk); return new Promise((r) => { globalThis.go = r; }); } }))
        \\  .then(() => out.push('piped'));
        \\'ok'
    );
    for (0..3) |_| {
        try collect(&page);
        try run(&page, "go(); 'ok'");
    }
    try collect(&page);
    try expectOut(&page, "[\"a\",\"b\",\"piped\"]");
}

test "a reader is kept by its async iterator" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    // Nothing but the iterator reaches the reader (or the stream).
    try run(&page, "globalThis.it = new ReadableStream({ start(c) { c.enqueue(1); c.enqueue(2); c.close(); } }).values(); 'ok'");
    try collect(&page);
    try run(&page, "it.next().then((r) => out.push(r.value)); 'ok'");
    try collect(&page);
    try run(&page, "it.next().then((r) => out.push(r.value)); it.next().then((r) => out.push(r.done)); 'ok'");
    try expectOut(&page, "[1,2,true]");
}

test "a for await suspended on a pending read keeps its stream" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    try run(&page,
        \\(async () => {
        \\  for await (const chunk of new ReadableStream({ start(c) { globalThis.source = c; } })) out.push(chunk);
        \\  out.push('done');
        \\})();
        \\'ok'
    );
    try collect(&page);
    try run(&page, "source.enqueue(1); 'ok'");
    try collect(&page);
    try run(&page, "source.enqueue(2); source.close(); 'ok'");
    try expectOut(&page, "[1,2,\"done\"]");
}

test "a stream lives as long as the controller script kept" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    try run(&page, "new ReadableStream({ start(c) { globalThis.c = c; } }, { highWaterMark: 3 }); 'ok'");
    try collect(&page);
    // A close with a chunk still queued leaves the stream readable (desired
    // size hwm - 1); reading the chunk then closes it (0).
    try run(&page,
        \\c.enqueue(1); out.push(c.desiredSize); c.close(); out.push(c.desiredSize);
        \\'ok'
    );
    try expectOut(&page, "[2,2]");
}

test "a transform stream lives as long as the readable side script kept" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    try run(&page,
        \\{
        \\  const ts = new TransformStream({ transform(chunk, c) { c.enqueue(chunk + '!'); } });
        \\  const writer = ts.writable.getWriter();
        \\  writer.write('a');
        \\  writer.close();
        \\  globalThis.reader = ts.readable.getReader();
        \\}
        \\'ok'
    );
    try collect(&page);
    try run(&page, "reader.read().then((v) => out.push(v.value)); reader.read().then((v) => out.push(v.done)); 'ok'");
    try expectOut(&page, "[\"a!\",true]");
}

test "a transform stream's writable side keeps it, and a write waits for its reader" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    // The write waits on backpressure until the readable side is read: script
    // keeps only the writer, and later the reader it gets back from a global.
    try run(&page,
        \\{
        \\  const ts = new TextDecoderStream();
        \\  globalThis.writer = ts.writable.getWriter();
        \\  globalThis.readable = ts.readable;
        \\}
        \\writer.write(new Uint8Array([104, 105])).then(() => out.push('written'));
        \\'ok'
    );
    try collect(&page);
    try run(&page, "readable.getReader().read().then((v) => out.push(v.value)); 'ok'");
    try collect(&page);
    try expectOut(&page, "[\"hi\",\"written\"]");
}

test "a tee branch script kept reads its source's chunks" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    try run(&page, "globalThis.branch = new ReadableStream({ start(c) { globalThis.source = c; } }).tee()[0]; 'ok'");
    try collect(&page);
    try run(&page,
        \\{ const r = branch.getReader(); r.read().then((v) => out.push(v.value)); r.read().then((v) => out.push(v.done)); }
        \\source.enqueue(7); source.close();
        \\'ok'
    );
    try expectOut(&page, "[7,true]");
}

test "a body read by text() with nothing else reaching its Response settles" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    try run(&page, "new Response(new ReadableStream({ start(c) { globalThis.source = c; } })).text().then((t) => out.push(t)); 'ok'");
    try collect(&page);
    try run(&page, "source.enqueue(new Uint8Array([104, 105])); 'ok'");
    try collect(&page);
    try run(&page, "source.close(); 'ok'");
    try expectOut(&page, "[\"hi\"]");
}

test "ReadableStream.from() over a pending async iterator keeps its stream" {
    var page: rounds_lib.Page = undefined;
    try startPage(&page);
    defer page.end();
    try run(&page,
        \\{
        \\  const it = { [Symbol.asyncIterator]() { return { next() { return new Promise((r) => { globalThis.go = r; }); } }; } };
        \\  ReadableStream.from(it).getReader().read().then((v) => out.push(v.value));
        \\}
        \\'ok'
    );
    try collect(&page);
    try run(&page, "go({ value: 'x', done: false }); 'ok'");
    try expectOut(&page, "[\"x\"]");
}
