//! A frame's document is parsed as its response body arrives, in a real
//! Browser over a real socket: the first chunk is in the frame's DOM before
//! the server sends the rest, and a Browser that ends - or a frame removed -
//! while the body arrives lets the body and its fetch go, with nothing
//! leaked (std.testing.allocator) and no fetch left to outlive its agent.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const browser_mod = @import("browser");

const net = std.Io.net;
const Io = std.Io;

/// A one-route HTTP server: GET /frame answers an HTML document in two
/// chunks, the second only once the test lets it go (`release`), so the
/// test, not the clock, decides when the rest of the body arrives.
const ChunkServer = struct {
    io: Io,
    server: net.Server,
    thread: ?std.Thread = null,
    port: u16,
    stop_flag: std.atomic.Value(bool) = .init(false),
    released: std.atomic.Value(bool) = .init(false),

    fn start(self: *ChunkServer) !void {
        const io = testing.io;
        const address: net.IpAddress = .{ .ip4 = net.Ip4Address.loopback(0) };
        const server = try address.listen(io, .{ .reuse_address = true });
        self.* = .{ .io = io, .server = server, .port = server.socket.address.getPort() };
        self.thread = try std.Thread.spawn(.{}, loop, .{self});
    }

    fn release(self: *ChunkServer) void {
        self.released.store(true, .release);
    }

    fn stop(self: *ChunkServer) void {
        self.release();
        self.stop_flag.store(true, .release);
        self.server.deinit(self.io);
        if (self.thread) |thread| thread.join();
    }

    fn loop(self: *ChunkServer) void {
        while (!self.stop_flag.load(.acquire)) {
            const stream = self.server.accept(self.io) catch |err| {
                if (err == error.SocketNotListening) break;
                continue;
            };
            self.serve(stream) catch {};
            stream.close(self.io);
        }
    }

    fn write(self: *ChunkServer, stream: net.Stream, bytes: []const u8) !void {
        var buffer: [0]u8 = .{};
        var writer = stream.writer(self.io, &buffer);
        writer.interface.writeAll(bytes) catch return error.WriteFailed;
        writer.interface.flush() catch return error.WriteFailed;
    }

    fn chunk(self: *ChunkServer, stream: net.Stream, bytes: []const u8) !void {
        var size: [16]u8 = undefined;
        try self.write(stream, try std.fmt.bufPrint(&size, "{x}\r\n", .{bytes.len}));
        try self.write(stream, bytes);
        try self.write(stream, "\r\n");
    }

    fn serve(self: *ChunkServer, stream: net.Stream) !void {
        var buf: [4096]u8 = undefined;
        var reader = stream.reader(self.io, &buf);
        reader.interface.fillMore() catch return;
        const request = reader.interface.buffered();
        if (!std.mem.startsWith(u8, request, "GET /frame")) {
            return self.write(stream, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        }
        try self.write(stream, "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n");
        try self.chunk(stream, "<!doctype html><p id=a>one</p><!--" ++ &@as([2048:0]u8, @splat('x')) ++ "-->");
        var waited: usize = 0;
        while (!self.released.load(.acquire) and waited < 2000) : (waited += 1) {
            self.io.sleep(.fromMilliseconds(5), .awake) catch {};
        }
        try self.chunk(stream, "<p id=b>two</p>");
        try self.write(stream, "0\r\n\r\n");
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

/// A page at the server's origin with one frame navigating to /frame,
/// returned once the frame's first chunk is in its document.
fn openFramedPage(server: *ChunkServer) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    var url_buf: [64]u8 = undefined;
    const page_url = try std.fmt.bufPrint(&url_buf, "http://127.0.0.1:{d}/page", .{server.port});
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><iframe src=\"/frame\"></iframe>", .{ .base_url = page_url });
    try waitFor(browser, "!!(frames[0] && frames[0].document.getElementById('a'))");
    return browser;
}

test "a frame's first chunk is in its document before the rest of the body arrives" {
    var server: ChunkServer = undefined;
    try server.start();
    defer server.stop();
    const browser = try openFramedPage(&server);
    defer browser.deinit();
    // The rest has not arrived: the document is still loading.
    try testing.expect(try truthy(browser, "frames[0].document.readyState === 'loading' && !frames[0].document.getElementById('b')"));
    server.release();
    try waitFor(browser, "frames[0].document.readyState === 'complete' && !!frames[0].document.getElementById('b')");
}

test "a Browser that ends while a frame's body arrives leaks neither the body nor its fetch" {
    var server: ChunkServer = undefined;
    try server.start();
    defer server.stop();
    const browser = try openFramedPage(&server);
    browser.deinit();
}

test "a frame removed while its body arrives stops parsing it" {
    var server: ChunkServer = undefined;
    try server.start();
    defer server.stop();
    const browser = try openFramedPage(&server);
    defer browser.deinit();
    try testing.expect(try truthy(browser, "(window.kept = frames[0].document, document.querySelector('iframe').remove(), true)"));
    server.release();
    var turns: usize = 0;
    while (turns < 30) : (turns += 1) _ = try browser.runEventLoopBlocking(10);
    try testing.expect(try truthy(browser, "!kept.getElementById('b')"));
}

test "a frame's streamed body is reported to its container's resource timing once it ends" {
    var server: ChunkServer = undefined;
    try server.start();
    defer server.stop();
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var url_buf: [64]u8 = undefined;
    const page_url = try std.fmt.bufPrint(&url_buf, "http://127.0.0.1:{d}/page", .{server.port});
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    // The container starts the navigation, so the container's global hears
    // its resource timing - at the body's end, long after the commit.
    try testing.expect(try truthy(browser, "(() => { const f = document.createElement('iframe'); f.src = '/frame'; document.body.append(f); return true; })()"));
    try waitFor(browser, "!!(frames[0] && frames[0].document.getElementById('a'))");
    server.release();
    try waitFor(browser, "frames[0].document.readyState === 'complete' && performance.getEntriesByType('resource').some(e => e.initiatorType === 'iframe' && e.name.endsWith('/frame'))");
}
