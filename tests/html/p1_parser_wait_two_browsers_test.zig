//! Two Browsers on two threads, each loading a page whose parser-blocking
//! classic script comes from a slow server, wait for their scripts at the
//! same time - each parser suspended at its script's end tag, with its event
//! loop running timers meanwhile - and both resume when their responses
//! arrive.
//!
//! HTML "an end tag whose tag name is script": while the pending
//! parsing-blocking script is not ready, "spin the event loop until ... the
//! script's ready to be parser-executed". Crane's document parser returns to
//! its caller there and resumes from the fetch's task (lane parser1). Before,
//! the navigation parser fetched the script synchronously, so the page's
//! thread ran nothing while it waited, and `loadHTML` returned only once the
//! whole document was parsed.
//!
//! Each Browser allocates from a DebugAllocator of its own (no stack traces),
//! which still fails the test on a leak; std.testing.allocator's lock would
//! make the two Browsers take turns (docs/lessons/
//! testing-a-shared-test-allocator-makes-two-browsers-take-turns.md).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

/// A loopback HTTP server that answers every request after `delay_ms`, one
/// connection per thread, so both Browsers' requests wait at once.
const SlowServer = struct {
    server: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    in_flight: std.atomic.Value(usize) = .init(0),
    most_in_flight: std.atomic.Value(usize) = .init(0),
    served: std.atomic.Value(usize) = .init(0),
    handlers: std.atomic.Value(usize) = .init(0),

    const delay_ms = 400;

    fn start() !*SlowServer {
        const self = try testing.allocator.create(SlowServer);
        errdefer testing.allocator.destroy(self);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
        var server = try address.listen(testing.io, .{ .reuse_address = true });
        errdefer server.deinit(testing.io);
        self.* = .{ .server = server };
        self.thread = try std.Thread.spawn(.{}, serve, .{ self, server });
        return self;
    }

    fn port(self: *const SlowServer) u16 {
        return self.server.socket.address.getPort();
    }

    fn stop(self: *SlowServer) void {
        self.stopping.store(true, .release);
        self.server.deinit(testing.io);
        self.thread.?.join();
        // Handler threads are detached: wait for the last to finish.
        while (self.handlers.load(.acquire) != 0) testing.io.sleep(.fromMilliseconds(5), .awake) catch {};
        testing.allocator.destroy(self);
    }

    fn serve(self: *SlowServer, listener: std.Io.net.Server) void {
        var server = listener;
        while (!self.stopping.load(.acquire)) {
            const stream = server.accept(testing.io) catch continue;
            _ = self.handlers.fetchAdd(1, .acq_rel);
            const handler = std.Thread.spawn(.{}, handle, .{ self, stream }) catch {
                stream.close(testing.io);
                _ = self.handlers.fetchSub(1, .acq_rel);
                continue;
            };
            handler.detach();
        }
    }

    fn handle(self: *SlowServer, stream: std.Io.net.Stream) void {
        defer _ = self.handlers.fetchSub(1, .acq_rel);
        defer stream.close(testing.io);
        self.reply(stream) catch {};
    }

    fn reply(self: *SlowServer, stream: std.Io.net.Stream) !void {
        var input: [4096]u8 = undefined;
        var reader = stream.reader(testing.io, &input);
        try reader.interface.fillMore();
        if (reader.interface.buffered().len == 0) return;
        const now = self.in_flight.fetchAdd(1, .acq_rel) + 1;
        defer _ = self.in_flight.fetchSub(1, .acq_rel);
        var most = self.most_in_flight.load(.acquire);
        while (now > most) most = self.most_in_flight.cmpxchgWeak(most, now, .acq_rel, .acquire) orelse break;
        try testing.io.sleep(.fromMilliseconds(delay_ms), .awake);
        const body = "globalThis.slowRan = true;";
        var output: [0]u8 = .{};
        var writer = stream.writer(testing.io, &output);
        var head: [256]u8 = undefined;
        try writer.interface.writeAll(try std.fmt.bufPrint(&head, "HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{body.len}));
        try writer.interface.writeAll(body);
        try writer.interface.flush();
        _ = self.served.fetchAdd(1, .release);
    }
};

const page =
    \\<!doctype html><body>
    \\<script>
    \\globalThis.ticks = 0;
    \\globalThis.ticksAtResume = -1;
    \\setInterval(() => { ticks++; }, 10);
    \\</script>
    \\<p id=before>before</p>
    \\<script src="/slow.js"></script>
    \\<p id=after>after</p>
    \\<script>globalThis.ticksAtResume = ticks;</script>
;

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Both threads reach a point before either goes on.
const Rendezvous = struct {
    arrived: std.atomic.Value(usize) = .init(0),
    failed: std.atomic.Value(bool) = .init(false),

    fn reached(self: *Rendezvous) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var waited: usize = 0;
        while (self.arrived.load(.acquire) < 2) : (waited += 1) {
            if (self.failed.load(.acquire)) return error.OtherThreadFailed;
            if (waited > 5000) return error.TimedOut;
            try testing.io.sleep(.fromMilliseconds(1), .awake);
        }
    }
};

fn loadAndWait(port: u16, together: *Rendezvous) !void {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer if (debug_allocator.deinit() == .leak) @panic("a Browser leaked");
    const allocator = debug_allocator.allocator();
    errdefer together.failed.store(true, .release);

    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    var url_buffer: [64]u8 = undefined;
    const base_url = try std.fmt.bufPrint(&url_buffer, "http://127.0.0.1:{d}/page.html", .{port});
    try context.loadHTML(page, .{ .base_url = base_url });

    // The parser stopped at the slow script's end tag and returned: the
    // document is loading, parsed up to the script, and the script has not run.
    try testing.expect(try truthy(browser, "document.readyState === 'loading'"));
    try testing.expect(try truthy(browser, "document.getElementById('before') !== null"));
    try testing.expect(try truthy(browser, "document.getElementById('after') === null"));
    try testing.expect(try truthy(browser, "globalThis.slowRan === undefined"));

    // Both parsers are waiting now.
    try together.reached();

    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, "document.readyState === 'complete'")) break;
        _ = try browser.runEventLoopBlocking(10);
    } else return error.TimedOut;
    try testing.expect(try truthy(browser, "globalThis.slowRan === true"));
    try testing.expect(try truthy(browser, "document.getElementById('after') !== null"));
    // The interval ran while the parser waited for the script.
    try testing.expect(try truthy(browser, "globalThis.ticksAtResume > 5"));
}

fn run(port: u16, together: *Rendezvous, failure: *?anyerror) void {
    loadAndWait(port, together) catch |err| {
        together.failed.store(true, .release);
        failure.* = err;
    };
}

test "two Browsers' parsers wait for their slow parser-blocking scripts at once, with their event loops running" {
    const server = try SlowServer.start();
    defer server.stop();
    var together: Rendezvous = .{};
    var failures = [2]?anyerror{ null, null };
    var threads: [2]std.Thread = undefined;
    for (&threads, 0..) |*thread, i| thread.* = try std.Thread.spawn(.{}, run, .{ server.port(), &together, &failures[i] });
    for (threads) |thread| thread.join();
    for (failures) |failure| if (failure) |err| return err;
    try testing.expectEqual(@as(usize, 2), server.served.load(.acquire));
    // Both requests were outstanding at the same time: neither Browser's
    // thread was blocked in its fetch while the other's request waited.
    try testing.expectEqual(@as(usize, 2), server.most_in_flight.load(.acquire));
}
