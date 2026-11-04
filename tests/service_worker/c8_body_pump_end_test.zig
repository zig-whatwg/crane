//! A service worker's response body pumps end themselves from inside their
//! own steps, and nothing of a pump is read after its end (lane crashes8).
//!
//! respondWith() hands the fetching thread a relay and reads the response's
//! body into it on the worker's thread (service_worker/fetch_event.zig):
//!
//! - an opaque response's internal body through `InternalBodyPump`, a reader
//!   of the body's pipe. Told of new bytes, it writes them to the relay; when
//!   the page's reader has gone the write fails and the pump ENDS - frees
//!   itself - inside that notification. Its notification then freed the
//!   bytes with the allocator it read from the freed pump
//!   (service-workers/service-worker/fetch-canvas-tainting-video.https.html
//!   crashed every time on the release runner: rawFree under
//!   body_pipe.notifyAll);
//! - a ReadableStream body through `BodyPump`, one read pending at a time.
//!   When the page's reader goes, a task on the worker's loop cancels the
//!   stream. The stream's cancel algorithm is script - a callback - and the
//!   microtask checkpoint after it runs the pending read's reaction, which
//!   ENDS the pump; the cancel then read the realm from the freed pump to
//!   mark its promise handled
//!   (service-workers/service-worker/fetch-event-respond-with-readable-stream.https.html
//!   crashed every time on the release runner: realm_entry.enter under
//!   markPromiseAsHandled).
//!
//! Both passed on the correctness runner by luck: its DebugAllocator never
//! reuses a freed slot and never poisons it, so the stale reads found the
//! old bytes. Here everything a pump frees comes from `Pages` (every
//! allocation its own mapping, unmapped when freed), so a read of a freed
//! pump faults at once
//! (docs/lessons/testing-a-use-after-free-that-reads-stale-bytes-passes-unmap-on-free.md);
//! the count of live allocations stands in for std.testing.allocator's leak
//! check.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const fetch = @import("fetch");
const browser_mod = @import("browser");
const sw = @import("service_worker");
const body_pipe = fetch.internal.body_pipe;
const BodyRelay = fetch.internal.service_worker_fetch.BodyRelay;

/// The page allocator, counting what is live: free unmaps.
const Pages = struct {
    live: std.atomic.Value(isize) = .init(0),

    fn allocator(self: *Pages) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    const inner = std.heap.page_allocator;

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Pages = @ptrCast(@alignCast(ctx));
        const made = inner.vtable.alloc(inner.ptr, len, alignment, ret) orelse return null;
        _ = self.live.fetchAdd(1, .monotonic);
        return made;
    }
    fn resize(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) bool {
        return inner.vtable.resize(inner.ptr, memory, alignment, new_len, ret);
    }
    fn remap(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) ?[*]u8 {
        return inner.vtable.remap(inner.ptr, memory, alignment, new_len, ret);
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Pages = @ptrCast(@alignCast(ctx));
        inner.vtable.free(inner.ptr, memory, alignment, ret);
        _ = self.live.fetchSub(1, .monotonic);
    }
};

/// The network end of an opaque body: counts its cancels.
const Producer = struct {
    cancelled: usize = 0,

    fn producer(self: *Producer) body_pipe.Producer {
        return .{ .context = self, .cancel = cancel };
    }

    fn cancel(context: *anyopaque) void {
        const self: *Producer = @ptrCast(@alignCast(context));
        self.cancelled += 1;
    }
};

test "an opaque body's pump whose page reader went ends inside the notification that told it, and nothing of it is read after" {
    var pages: Pages = .{};
    var producer: Producer = .{};
    {
        const a = pages.allocator();
        const source = try body_pipe.PipeSource.create(a);
        source.producer = producer.producer();
        // The Response's own body, a reader of the network's source.
        const body = try fetch.internal.Body.fromPipe(a, try source.branch());
        // The relay: the pump writes; the test is its reader on the page.
        const relay = try BodyRelay.create(a);
        try sw.fetch_event.InternalBodyPump.start(body, relay);
        // The page's reader goes (the video's load was cancelled).
        relay.cancel();
        relay.release();

        // More of the body arrives: the pump hears it, finds nobody
        // reading, and ends - its tee and the relay's last reference go.
        source.push("more bytes");

        // The Response's own body still reads it: the transfer goes on.
        try testing.expectEqual(@as(usize, 0), producer.cancelled);
        body.deinit();
    }
    // The last reader went: the transfer stopped, and nothing is left.
    try testing.expectEqual(@as(usize, 1), producer.cancelled);
    try testing.expectEqual(@as(isize, 0), pages.live.load(.monotonic));
}

test "an opaque body's pump that is its body's last reader: its end inside the network's delivery stops the transfer, and the source goes after the delivery" {
    var pages: Pages = .{};
    var producer: Producer = .{};
    {
        const a = pages.allocator();
        const source = try body_pipe.PipeSource.create(a);
        source.producer = producer.producer();
        const body = try fetch.internal.Body.fromPipe(a, try source.branch());
        const relay = try BodyRelay.create(a);
        try sw.fetch_event.InternalBodyPump.start(body, relay);
        // The Response object goes first (collected): the pump's tee is the
        // only reader left.
        body.deinit();
        try testing.expectEqual(@as(usize, 0), producer.cancelled);
        relay.cancel();
        relay.release();

        source.push("more bytes");
    }
    try testing.expectEqual(@as(usize, 1), producer.cancelled);
    try testing.expectEqual(@as(isize, 0), pages.live.load(.monotonic));
}

test "an opaque body's pump that is its body's last reader hears the end: the relay closes, and the source goes after the delivery" {
    var pages: Pages = .{};
    var producer: Producer = .{};
    var relay_end: BodyRelay.End = .open;
    {
        const a = pages.allocator();
        const source = try body_pipe.PipeSource.create(a);
        source.producer = producer.producer();
        const body = try fetch.internal.Body.fromPipe(a, try source.branch());
        const relay = try BodyRelay.create(a);
        try sw.fetch_event.InternalBodyPump.start(body, relay);
        body.deinit();

        source.push("all of it");
        source.finish();

        // The page's reader drains the relay: the whole body, closed.
        const collected = try relay.collect(a, 1000);
        defer a.free(collected);
        try testing.expectEqualStrings("all of it", collected);
        relay_end = relay.end;
        relay.release();
    }
    try testing.expectEqual(BodyRelay.End.closed, relay_end);
    // It ended on its own: nothing was cancelled.
    try testing.expectEqual(@as(usize, 0), producer.cancelled);
    try testing.expectEqual(@as(isize, 0), pages.live.load(.monotonic));
}

const page_url = "http://c8-body-pump.test/page.html";

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        std.debug.print("false: {s}\n", .{source});
        return error.ScriptAnsweredFalse;
    }
}

test "a stream body's pump cancelled for the page: the read its cancel settles ends the pump, and the cancel reads nothing of it after" {
    var pages: Pages = .{};
    {
        const browser = try browser_mod.Browser.init(pages.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const context = browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
        const realm = browser.getRealm() orelse return error.NoRealm;

        // A worker realm's door, which the relay's cancel is posted through
        // (CancelWatch). A window realm has none: the test gives this one a
        // sink and runs what is posted to it, as the worker's loop does - a
        // task outside any realm.
        const sink = try runtime.TaskSink.create(pages.allocator());
        realm.task_sink = sink;
        defer {
            realm.task_sink = null;
            sink.close();
            sink.release();
        }

        // A body whose read stays pending, and whose cancel algorithm is
        // script: the checkpoint after it runs the read's reaction.
        const held = try browser.evaluateScript(
            \\globalThis.cancels = 0;
            \\globalThis.responseBody = new ReadableStream({ cancel() { globalThis.cancels++; } });
            \\responseBody
        );
        defer held.release();
        const stream = engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAStream;
        const relay = try BodyRelay.create(pages.allocator());
        try sw.fetch_event.BodyPump.start(realm, stream, relay);

        // The page's reader goes: the cancel is posted to the worker's loop.
        relay.cancel();
        relay.release();
        var tasks: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
        defer tasks.deinit(testing.allocator);
        try sink.takeAll(&tasks, testing.allocator);
        try testing.expectEqual(@as(usize, 1), tasks.items.len);
        for (tasks.items) |task| task.run(task.data);

        // The stream's underlying source heard the cancel, once.
        try expectScript(browser, "cancels === 1");
    }
    try testing.expectEqual(@as(isize, 0), pages.live.load(.monotonic));
}
