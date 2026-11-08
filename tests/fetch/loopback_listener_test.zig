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
/// taken (and reset) before, reset with the listener - or, on Linux, never
/// answered at all. It waits for the answer before closing its own end, so
/// it leaves no TIME_WAIT either; one that has not come in `give_up_ms` never
/// will, and the client resets its own end instead.
///
/// The unanswered case (server1, Linux 7.0, lane linux1 b2): the client's
/// final ACK reaches the listener while close() is under way. tcp_close sets
/// TCP_CLOSE, whose tcp_set_state releases a port-0 listener's bind bucket
/// (inet_put_port) before the state itself is stored; tcp_v4_rcv still sees
/// TCP_LISTEN and calls tcp_check_req, where tcp_v4_syn_recv_sock's
/// __inet_inherit_port finds no bucket (-ENOENT) and fails (TcpExtListenDrops
/// counts it); with tcp_abort_on_overflow 0 the ACK is dropped and the
/// request kept, and inet_csk_listen_stop resets only the accept queue, so
/// nothing ever answers. The client stays ESTABLISHED with one segment in
/// (the SYN-ACK) and no peer: 4 of 3,000 racing clients in a Python copy of
/// this test, connect() returning 7-9 us after close(). macOS answers every
/// such client (the 3,000 stops pass in every gate there).
fn connectOnce(port: u16) void {
    const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(port) };
    const stream = address.connect(std.testing.io, .{ .mode = .stream }) catch return;
    var buffer: [64]u8 = undefined;
    var reader = stream.reader(std.testing.io, &buffer);
    while (true) {
        var ready: [1]std.posix.pollfd = .{.{ .fd = stream.socket.handle, .events = std.posix.POLL.IN, .revents = 0 }};
        const n = std.posix.poll(&ready, give_up_ms) catch 0;
        if (n == 0) {
            loopback_listener.resetClose(stream);
            return;
        }
        reader.interface.fillMore() catch {
            stream.close(std.testing.io);
            return;
        };
    }
}

/// Every other answer is sent by the time the listener's close returns: the
/// bound only ends the wait for the one that never comes.
const give_up_ms = 2 * std.time.ms_per_s;

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

test "a racing client gives up on a connection nobody will ever answer" {
    // A listener that never accepts keeps the connection in its backlog,
    // ESTABLISHED and silent - what Linux leaves a client whose final ACK
    // raced the listener's close (server1, lane linux1 b2: no reset ever
    // comes). The client must give up rather than wait forever.
    var listener = try LoopbackListener.open(.{});
    defer listener.close();
    const started = clock.monotonicMillis();
    connectOnce(listener.port());
    try std.testing.expect(clock.monotonicMillis() - started < 30 * std.time.ms_per_s);
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
