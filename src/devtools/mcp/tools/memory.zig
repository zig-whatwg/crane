//! take_heapsnapshot - chrome-devtools-mcp v1.13.0's src/tools/memory.ts
//! (takeHeapSnapshot; Copyright 2025 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md) over Puppeteer's CdpPage.captureHeapSnapshot
//! (puppeteer-core 25.17.0 src/cdp/Page.ts, Copyright 2017 Google Inc.,
//! Apache-2.0): captures the page's V8 heap snapshot via
//! `HeapProfiler.takeHeapSnapshot` while collecting
//! `HeapProfiler.addHeapSnapshotChunk` events, normalizes the path extension
//! to `.heapsnapshot`, writes owner-only under Crane's path policy
//! (`paths.zig`), and reports `Heap snapshot saved to <path>`.

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;

pub const list = [_]Tool{
    .{
        .name = "take_heapsnapshot",
        .page_tool = true,
        .blocked_by_dialog = true,
        .files = &.{.{ .name = "filePath" }},
        .run = takeHeapSnapshot,
    },
};

/// V8 heap snapshot walk timeout (generous for debug / TSan builds).
const heap_snapshot_timeout_ms: u32 = 60_000;

fn takeHeapSnapshot(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const path = registry.stringArg(args, "filePath") orelse return ctx.fail("The \"path\" argument must be of type string. Received undefined", .{});

    var capture: session_mod.HeapCapture = .{
        .session_id = target.session_id,
        .allocator = ctx.session.allocator,
    };
    defer capture.chunks.deinit(ctx.session.allocator);
    ctx.session.heap_capture = &capture;
    defer ctx.session.heap_capture = null;

    var r = try ctx.session.client.call(
        "HeapProfiler.takeHeapSnapshot",
        "{\"reportProgress\":false,\"treatGlobalObjectsAsRoots\":true,\"captureNumericValue\":false}",
        target.session_id,
        heap_snapshot_timeout_ms,
    );
    defer r.deinit();
    if (r.errorMessage()) |msg| return ctx.fail("{s}", .{msg});
    if (capture.failed) return error.OutOfMemory;

    const saved = ctx.session.paths.saveFile(ctx.arena, capture.chunks.items, path, ".heapsnapshot") catch |err| switch (err) {
        error.Denied => return ctx.fail("{s}", .{ctx.session.paths.message}),
        error.OutOfMemory => return error.OutOfMemory,
    };
    try response.line("Heap snapshot saved to {s}", .{saved});
}
