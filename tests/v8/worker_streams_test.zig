//! Streams made in a worker realm.
//!
//! encoding/streams/decode-bad-chunks.any.js's worker variant crashed the
//! runner: `new TextDecoderStream()` in a DedicatedWorkerGlobalScope sets up
//! its TransformStream's writable side, and setUpController wrapped the
//! controller's AbortController, let the wrapper go, and only then cloned it
//! - a collection in between freed it. This makes the same streams in a
//! worker realm under GC pressure and uses them. It did NOT reproduce the
//! crash: a release V8 has no --gc-interval (it needs
//! V8_ENABLE_ALLOCATION_TIMEOUT), so no schedule puts a collection in that
//! window. The red is the WPT file, run serially; the gap itself is closed
//! and pinned in tests/v8/streams_wrap_test.zig (Realm.wrap refuses weak
//! classes). This stays as a worker-realm streams check under pressure.

const std = @import("std");
/// Every worker realm has an event loop; this test drives none.
const inline_task_loop = @import("inline_task_loop.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");

var set_up = false;

fn setup() void {
    if (set_up) return;
    set_up = true;
    // Before V8 starts (the first createAgent starts it): every collection a
    // full one, and a 1 MB young generation, so collections land inside the
    // short windows where a wrapper is only weakly held. A release V8 has no
    // --gc-interval (that needs V8_ENABLE_ALLOCATION_TIMEOUT), so this is
    // pressure, not a schedule. V8 freezes its flags when it starts (setting
    // one after is a fatal CHECK), and tests/v8 shares one process, so the
    // pressure applies only when this file is the first to start V8 - the
    // -Dtest-file run of it alone.
    if (!v8.ffi.v8_Platform_IsInitialized()) v8.ffi.v8_SetFlagsFromString("--stress-compaction");
    runtime.initializeRuntime(std.heap.page_allocator);
    v8.context_manager.init(std.heap.page_allocator) catch {};
}

const Reports = struct {
    count: usize = 0,
    buffer: [256]u8 = undefined,
    len: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.len = @min(info.message.len, self.buffer.len);
        @memcpy(self.buffer[0..self.len], info.message[0..self.len]);
    }
};

fn evalIn(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    return protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, .{ .report = Reports.report, .host = &reports }) catch |err| {
        if (reports.count > 0) std.debug.print("{s} threw: {s}\n", .{ source, reports.buffer[0..reports.len] });
        return err;
    };
}

test "a TextDecoderStream made in a worker realm has live readable and writable sides" {
    setup();
    const agent = try v8.worker_realm.createAgent();
    defer v8.worker_realm.destroyAgent(agent);
    const made = try v8.worker_realm.createWorkerRealm(agent, .{
        .url = "http://web-platform.test:8000/encoding/streams/w.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .allocator = std.heap.page_allocator,
    });
    defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);

    const made_streams = try evalIn(made.realm,
        \\globalThis.tds = new TextDecoderStream();
        \\globalThis.writer = tds.writable.getWriter();
        \\globalThis.reader = tds.readable.getReader();
        \\[typeof tds, typeof writer.write, typeof reader.read, tds.encoding].join()
    );
    defer std.testing.allocator.free(made_streams);
    try std.testing.expectEqualStrings("object,function,function,utf-8", made_streams);

    // A second stream, and a bad chunk written to the first: the worker
    // variant's steps.
    const again = try evalIn(made.realm,
        \\const second = new TextDecoderStream();
        \\writer.write(undefined).catch(() => {});
        \\reader.read().catch(() => {});
        \\[typeof second.writable.getWriter, typeof second.readable.getReader].join()
    );
    defer std.testing.allocator.free(again);
    try std.testing.expectEqualStrings("function,function", again);

    // The WPT file makes a stream per bad chunk, with collections between:
    // anything a stream keeps without a reason to live is freed under it.
    for (0..64) |_| {
        const round = try evalIn(made.realm,
            \\for (const chunk of [undefined, null, 3.14, {}, [65]]) {
            \\  const s = new TextDecoderStream();
            \\  const w = s.writable.getWriter();
            \\  const r = s.readable.getReader();
            \\  w.write(chunk).catch(() => {});
            \\  r.read().catch(() => {});
            \\}
            \\'ok'
        );
        defer std.testing.allocator.free(round);
        try std.testing.expectEqualStrings("ok", round);
        protocol.requestGarbageCollection(agent);
        protocol.performMicrotaskCheckpoint(agent) catch {};
    }
}

test "a TextDecoderStream keeps its TransformStream through a collection" {
    setup();
    const agent = try v8.worker_realm.createAgent();
    defer v8.worker_realm.destroyAgent(agent);
    const made = try v8.worker_realm.createWorkerRealm(agent, .{
        .url = "http://web-platform.test:8000/encoding/streams/w.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .allocator = std.heap.page_allocator,
    });
    defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);

    // Script holds the streams, never their TransformStreams - those are
    // internal slots ([[transform]]), and nothing else keeps them.
    const kept = try evalIn(made.realm,
        \\globalThis.keep = [];
        \\for (let i = 0; i < 32; i++) keep.push(new TextDecoderStream(), new TextEncoderStream());
        \\String(keep.length)
    );
    defer std.testing.allocator.free(kept);
    try std.testing.expectEqualStrings("64", kept);
    for (0..3) |_| {
        protocol.requestGarbageCollection(agent);
        protocol.performMicrotaskCheckpoint(agent) catch {};
    }
    // Fill the slab with new objects: a freed TransformStream's slot is
    // someone else's now.
    const churn = try evalIn(made.realm,
        \\for (let i = 0; i < 64; i++) new AbortController();
        \\'churned'
    );
    defer std.testing.allocator.free(churn);
    const used = try evalIn(made.realm,
        \\let ok = 0;
        \\for (const s of keep) {
        \\  if (s.readable instanceof ReadableStream && s.writable instanceof WritableStream &&
        \\      typeof s.readable.getReader().read === 'function' && typeof s.writable.getWriter().write === 'function') ok++;
        \\}
        \\String(ok)
    );
    defer std.testing.allocator.free(used);
    try std.testing.expectEqualStrings("64", used);
}
