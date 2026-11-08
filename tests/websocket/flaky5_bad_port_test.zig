//! Lane flaky5: a WebSocket to a bad port is blocked before any connection.
//!
//! WebSockets "establish a WebSocket connection" fetches its request, and
//! Fetch's main fetch step 7 makes it a network error "if should request be
//! blocked due to a bad port" - before a name is looked up or a connection
//! made. Crane checked the request against CSP and Mixed Content there but
//! not against the port list, so each of websockets/Create-blocked-port.any.js's
//! 83 "blocked" sockets looked its host up and connected: refused on most
//! ports, and answered on any port a service listens on (sshd's 22 on the
//! pool hosts: wss://web-platform.test:22 got as far as a TLS error). The test
//! below listens on 10080 (Fetch's "amanda", a bad port a test can bind) and
//! answers nothing: a socket to it must fail with no connection accepted.
const std = @import("std");
const io = std.testing.io;
const Browser = @import("browser").Browser;
const engine = @import("engine");

const bad_port: u16 = 10080;

/// A listener on the bad port that counts the connections it is offered.
const Listener = struct {
    server: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    accepted: std.atomic.Value(u32) = .init(0),

    fn serve(self: *Listener) void {
        while (true) {
            const stream = self.server.accept(io) catch continue;
            stream.close(io);
            if (self.stopping.load(.acquire)) return;
            _ = self.accepted.fetchAdd(1, .acq_rel);
        }
    }

    /// Wake the accept thread with a connection of the test's own, join it,
    /// then close the listener.
    fn stop(self: *Listener) void {
        self.stopping.store(true, .release);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(bad_port) };
        if (address.connect(io, .{ .mode = .stream })) |wake| {
            if (self.thread) |thread| thread.join();
            wake.close(io);
        } else |_| {
            if (self.thread) |thread| thread.join();
        }
        self.server.deinit(io);
    }
};

fn evaluate(browser: *Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    return engine.toBoolean(browser.getRealm().?, held.borrow());
}

fn blockedBeforeConnecting() !void {
    const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(bad_port) };
    var listener: Listener = .{ .server = address.listen(io, .{ .reuse_address = true }) catch return error.SkipZigTest };
    listener.thread = try std.Thread.spawn(.{}, Listener.serve, .{&listener});
    defer listener.stop();

    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const url = "http://127.0.0.1/flaky5.html";
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = url });
    const held = try browser.evaluateScript(
        \\globalThis.events = [];
        \\const socket = new WebSocket('ws://127.0.0.1:10080/echo');
        \\socket.onopen = () => events.push('open');
        \\socket.onerror = () => events.push('error');
        \\socket.onclose = e => events.push('close ' + e.code + ' ' + e.wasClean);
    );
    held.release();
    var closed = false;
    for (0..300) |_| {
        if (try evaluate(browser, "events.some(e => e.startsWith('close'))")) {
            closed = true;
            break;
        }
        _ = try browser.runEventLoopBlocking(10);
    }
    try std.testing.expect(closed);
    try std.testing.expect(try evaluate(browser, "events.join() === 'error,close 1006 false'"));
    // Give a connection the socket might have started the time to arrive.
    _ = try browser.runEventLoopBlocking(50);
    try std.testing.expectEqual(@as(u32, 0), listener.accepted.load(.acquire));
}

test "a WebSocket to a bad port fails with no connection made (Fetch main fetch step 7)" {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            blockedBeforeConnecting() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
