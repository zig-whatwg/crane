//! A Response dropped while its body transfer is still open, then collected
//! by a collection V8 delivers BY TASK, in a real Browser over a real socket
//! (lane v8up b6).
//!
//! The Response's finalizer is its teardown: nobody reads the body any more,
//! so the transfer is cancelled, and the cancelled load is reported to the
//! page's Resource Timing buffer (src/fetch AsyncFetch.stopProducing ->
//! endBody -> FetchJob.bodyEnded; "Chromium's HandleLoaderError reports a
//! cancelled load"). Fetch 5.7 "Garbage collection" lets the user agent
//! terminate a fetch whose termination script cannot observe through
//! fetch()'s arguments and return value; this fetch()'s promise has settled
//! and its Response is unreachable.
//!
//! Reporting the entry writes a JS object. V8 15.7 runs a collection's second
//! pass - where the adapter ran the finalizer - under
//! DisallowJSObjectModification, in the task it posts for every collection
//! the embedder did not force, and the write was fatal there: "Check failed:
//! AllowJSObjectModification::IsAllowed(isolate)" (3 cookies files in the
//! lane's sweep). The finalizer now runs at the agent's safe point, after
//! that task (v8_wrapper.cpp `runQueuedFinalizers`).
//!
//! The collection's trigger: a moderate memory-pressure notice
//! (engine.notifyMemoryPressure .moderate = Isolate::
//! MemoryPressureNotification(kModerate)), which starts an incremental
//! collection that V8's marking job finishes in foreground tasks - nothing is
//! collected before the notice returns, and the second pass is a posted task
//! the Browser's event loop pumps. Never a forced, synchronous one.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const browser_mod = @import("browser");

const net = std.Io.net;
const LoopbackListener = @import("loopback_listener").LoopbackListener;
const Io = std.Io;

/// A one-route HTTP server: GET /body answers a chunked body whose first
/// chunk goes at once and whose end waits for the test (`release`), so the
/// transfer stays open for as long as the test needs.
const OpenBodyServer = struct {
    io: Io,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    port: u16,
    released: std.atomic.Value(bool) = .init(false),

    fn start(self: *OpenBodyServer) !void {
        const io = testing.io;
        const listener = try LoopbackListener.open(.{});
        self.* = .{ .io = io, .listener = listener, .port = listener.port() };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, loop, .{self});
    }

    /// Stop the accept thread, then close the listener - in that order
    /// (tests/support/loopback_listener.zig).
    fn stop(self: *OpenBodyServer) void {
        self.released.store(true, .release);
        self.listener.stop();
        if (self.thread) |thread| thread.join();
        self.listener.close();
    }

    fn loop(self: *OpenBodyServer) void {
        while (self.listener.accept()) |stream| {
            self.serve(stream) catch {};
            stream.close(self.io);
        }
    }

    fn write(self: *OpenBodyServer, stream: net.Stream, bytes: []const u8) !void {
        var buffer: [0]u8 = .{};
        var writer = stream.writer(self.io, &buffer);
        writer.interface.writeAll(bytes) catch return error.WriteFailed;
        writer.interface.flush() catch return error.WriteFailed;
    }

    fn serve(self: *OpenBodyServer, stream: net.Stream) !void {
        var buf: [4096]u8 = undefined;
        var reader = stream.reader(self.io, &buf);
        reader.interface.fillMore() catch return;
        const request = reader.interface.buffered();
        if (!std.mem.startsWith(u8, request, "GET /body")) {
            return self.write(stream, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        }
        try self.write(stream, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nCache-Control: no-store\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n");
        try self.write(stream, "5\r\nfirst\r\n");
        var waited: usize = 0;
        while (!self.released.load(.acquire) and waited < 6000) : (waited += 1) {
            self.io.sleep(.fromMilliseconds(5), .awake) catch {};
        }
        // The client has usually cancelled by now: the write fails, and the
        // connection closes either way.
        try self.write(stream, "4\r\nlast\r\n0\r\n\r\n");
    }
};

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 500) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

const body_entries = "performance.getEntriesByType('resource').filter(function (e) { return e.name.endsWith('/body'); }).length";

test "a Response dropped with its body transfer open is finalized after a collection delivered by task: the cancelled load is reported, and nothing dies" {
    var server: OpenBodyServer = undefined;
    try server.start();
    defer server.stop();

    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var url_buf: [64]u8 = undefined;
    const page_url = try std.fmt.bufPrint(&url_buf, "http://127.0.0.1:{d}/page", .{server.port});
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><title>open body</title>", .{ .base_url = page_url });

    // fetch() settles with the Response when its headers arrive; the reaction
    // keeps nothing of it, so from here no script reaches the Response, and
    // its body - one chunk in, the rest held by the server - is unread.
    {
        const started = try browser.evaluateScript(
            \\window.state = 'pending';
            \\fetch('/body').then(function (r) { window.state = 'headers:' + r.status; }, function () { window.state = 'failed'; });
            \\undefined
        );
        started.release();
    }
    try waitFor(browser, "window.state === 'headers:200'");
    // The transfer is open: the load has not ended for Resource Timing.
    try testing.expect(try truthy(browser, body_entries ++ " === 0"));

    // The collection, by task, and the event loop's turns: V8's marking
    // tasks, its second-pass task, then the agent's safe point, where the
    // Response's teardown cancels the transfer and reports the load.
    const agent = browser.getAgent() orelse return error.NoAgent;
    var rounds: usize = 0;
    const reported = while (rounds < 40) : (rounds += 1) {
        engine.notifyMemoryPressure(agent, .moderate);
        var turns: usize = 0;
        while (turns < 100) : (turns += 1) {
            _ = try browser.runEventLoopBlocking(10);
            if (try truthy(browser, body_entries ++ " !== 0")) break;
        }
        if (try truthy(browser, body_entries ++ " !== 0")) break true;
    } else false;
    if (!reported) {
        std.debug.print("the dropped Response's load was never reported: {d} moderate memory-pressure rounds\n", .{rounds});
        return error.DroppedResponseNeverFinalized;
    }
    // Reported once, to the page that is still there.
    try testing.expect(try truthy(browser, body_entries ++ " === 1"));
    try testing.expect(try truthy(browser, "window.state === 'headers:200'"));
}
