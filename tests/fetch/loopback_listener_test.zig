//! tests/support/loopback_listener.zig: a fixture's accept loop stops
//! without a race. The order it replaces - set the stop flag, close the
//! listener to unblock accept(), join - panicked when the thread reached
//! accept() after the close (EBADF is errnoBug in Zig's Io.Threaded):
//! tests-fetch "TestServer - WebSocket URL", FLAKY in lane tstate1's gates
//! (2026-11-02), which starts a server and stops it at once.
const std = @import("std");
const clock = @import("clock");
const loopback_listener = @import("loopback_listener");
const LoopbackListener = loopback_listener.LoopbackListener;

/// A fixture's accept loop, reduced: every connection is counted and
/// closed - with a reset, so that thousands of rounds leave no TIME_WAIT to
/// use up the host's ephemeral ports.
const Loop = struct {
    listener: LoopbackListener,
    served: std.atomic.Value(u32) = .init(0),

    fn run(self: *Loop) void {
        while (self.listener.accept()) |stream| {
            _ = self.served.fetchAdd(1, .monotonic);
            loopback_listener.resetClose(stream);
        }
    }
};

/// A client connecting while the listener stops: refused once it closed,
/// taken (and reset) before, or reset with the listener. It waits for that
/// end before closing its own, so it leaves no TIME_WAIT either.
fn connectOnce(port: u16) void {
    const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(port) };
    const stream = address.connect(std.testing.io, .{ .mode = .stream }) catch return;
    defer stream.close(std.testing.io);
    var buffer: [64]u8 = undefined;
    var reader = stream.reader(std.testing.io, &buffer);
    while (true) reader.interface.fillMore() catch return;
}

test "an accept loop stops 3,000 times - at once after it starts, and with a client racing the stop" {
    for (0..3000) |round| {
        var loop: Loop = .{ .listener = try LoopbackListener.open(.{}) };
        const thread = try std.Thread.spawn(.{}, Loop.run, .{&loop});
        // Every other round a client connects while the loop stops; the
        // others stop it before its thread may even have reached accept().
        const racer: ?std.Thread = if (round % 2 == 1) try std.Thread.spawn(.{}, connectOnce, .{loop.listener.port()}) else null;
        loop.listener.stop();
        thread.join();
        loop.listener.close();
        if (racer) |r| r.join();
    }
}

test "accept hands over every connection until the listener stops" {
    var loop: Loop = .{ .listener = try LoopbackListener.open(.{}) };
    const thread = try std.Thread.spawn(.{}, Loop.run, .{&loop});
    for (0..3) |_| connectOnce(loop.listener.port());
    const deadline = clock.monotonicMillis() + 10 * std.time.ms_per_s;
    while (loop.served.load(.monotonic) < 3) {
        if (clock.monotonicMillis() >= deadline) break;
        clock.sleep(std.time.ns_per_ms);
    }
    loop.listener.stop();
    thread.join();
    loop.listener.close();
    // stop()'s own connection is not handed over.
    try std.testing.expectEqual(@as(u32, 3), loop.served.load(.monotonic));
}
