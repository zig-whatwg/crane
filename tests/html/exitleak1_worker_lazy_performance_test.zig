//! A dedicated worker that never read `performance` ends with a fetch body
//! still unread: the Performance its realm's teardown makes is freed with
//! the worker's global scope (lane exitleak1).
//!
//! A worker's global scope makes its Performance on first use
//! (WorkerGlobalScope.settingsPerformance) and keeps it by a traced edge.
//! When the first use is native - a fetch body ended while the worker's
//! realm is torn down asks for the global's time origin
//! (relativeCoarseTimeOfRealm) and its timeline - the realm's wrapper cache
//! takes no wrapper any more, so the Performance stays unwrapped, and the
//! edge was all that held it: its state and the timing entry it buffered
//! leaked. Codex row 115's xw1 test found it (2-8 allocations per run after
//! the cache fix). The global scope now frees a Performance it made that
//! never got a wrapper, guarded by the slot's generation.
//!
//! The response comes from a loopback server that sends its headers and
//! part of its body, then never finishes; the worker keeps the reader.
//! Each round runs a whole Browser on a thread of its own (tests/html is one
//! executable: a fresh thread has no per-thread state left by others).

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const clock = @import("clock");

const Server = struct {
    socket: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),

    fn start() !*Server {
        const self = try testing.allocator.create(Server);
        errdefer testing.allocator.destroy(self);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
        var socket = try address.listen(testing.io, .{ .reuse_address = true });
        errdefer socket.deinit(testing.io);
        self.* = .{ .socket = socket };
        self.thread = try std.Thread.spawn(.{}, serve, .{ self, socket });
        return self;
    }

    fn stop(self: *Server) void {
        self.stopping.store(true, .release);
        self.socket.deinit(testing.io);
        self.thread.?.join();
        testing.allocator.destroy(self);
    }

    fn port(self: *const Server) u16 {
        return self.socket.socket.address.getPort();
    }

    fn serve(self: *Server, listener: std.Io.net.Server) void {
        var socket = listener;
        const stream = socket.accept(testing.io) catch return;
        defer stream.close(testing.io);
        self.answer(stream) catch {};
    }

    /// Headers and the first 16 KiB of a 1 MiB body, then nothing more until
    /// the test stops the server.
    fn answer(self: *Server, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        var output: [0]u8 = .{};
        var writer = stream.writer(testing.io, &output);
        try writer.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 1048576\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n");
        const part = [_]u8{'a'} ** 16384;
        try writer.interface.writeAll(&part);
        try writer.interface.flush();
        while (!self.stopping.load(.acquire)) clock.sleep(std.time.ns_per_ms);
    }
};

fn round() !void {
    const server = try Server.start();
    defer server.stop();
    var base_buf: [64]u8 = undefined;
    const base = try std.fmt.bufPrint(&base_buf, "http://127.0.0.1:{d}/", .{server.port()});
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(base, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = base });
    // The worker reads the first chunk and keeps its reader; it never reads
    // `performance`, so its global scope has made none when the Browser ends.
    const script = try std.fmt.allocPrint(testing.allocator,
        \\globalThis.state = 'pending';
        \\const source = "fetch('{s}body').then(r => {{ self.reader = r.body.getReader(); return reader.read(); }})" +
        \\  ".then(first => postMessage(first.done ? 'done' : 'read'), e => postMessage('failed ' + e));";
        \\const worker = new Worker(URL.createObjectURL(new Blob([source], {{ type: 'text/javascript' }})));
        \\worker.onmessage = e => {{ state = e.data; }};
        \\worker.onerror = () => {{ state = 'worker error'; }};
    , .{base});
    defer testing.allocator.free(script);
    try page.runScript(script);
    for (0..500) |_| {
        _ = try browser.runEventLoopBlocking(10);
        const state = try page.evaluateScriptToString("state", testing.allocator);
        defer testing.allocator.free(state);
        if (std.mem.eql(u8, state, "pending")) continue;
        try testing.expectEqualStrings("read", state);
        // The reader, the body's pipe and the transfer stay alive: the
        // Browser ends now (deferred), the worker's realm with it.
        return;
    }
    return error.StreamDidNotStart;
}

fn onFreshThread() !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            for (0..3) |_| round() catch |err| {
                out.* = err;
                return;
            };
        }
    }.run, .{&result});
    thread.join();
    try result;
}

test "a dedicated worker ended with an unread fetch body frees the Performance its teardown made" {
    try onFreshThread();
}
