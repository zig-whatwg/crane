//! A loopback TCP listener for test fixtures, whose accept loop stops
//! without a race (module `loopback_listener`, imported by every test
//! directory's root; build.zig addTestRoot).
//!
//! The fixtures' common shape set a stop flag, closed the listener "to
//! unblock accept()", and joined the thread in accept(). That raced the
//! thread: an accept() begun after the close gets EBADF, which Zig's
//! Io.Threaded treats as a programmer bug (errnoBug) and panics on in Debug,
//! and the closed descriptor's number may already belong to another file -
//! tests-fetch "TestServer - WebSocket URL" panicked that way in lane
//! tstate1's gates (2026-11-02). Here `stop` wakes the thread from accept()
//! with a connection of its own, the owner joins the thread, and only then
//! does `close` close the listener: no thread can be in accept() on a closed
//! descriptor.
//!
//! The wake-up connection leaves no TIME_WAIT behind - accept() resets it
//! (SO_LINGER 0), or the listener's close does if no thread took it, and its
//! own end is closed only after that - so stopping many listeners does not
//! use up the host's ephemeral ports: a first version that closed its end at
//! once ran a stress test of 3,000 stops into EADDRNOTAVAIL within seconds
//! when four copies ran together (lane fixes1).
//!
//!     // start:  self.listener = try LoopbackListener.open(.{});
//!     //         thread = try std.Thread.spawn(.{}, serve, .{self});
//!     // serve:  while (self.listener.accept()) |stream| { ... }
//!     // stop:   self.listener.stop(); thread.join(); self.listener.close();
const std = @import("std");

pub const LoopbackListener = struct {
    server: std.Io.net.Server,
    stopping: std.atomic.Value(bool) = .init(false),
    /// `stop`'s end of its wake-up connection, until `close`.
    wake: ?std.Io.net.Stream = null,

    pub const Options = struct {
        /// SO_REUSEADDR and SO_REUSEPORT, as `std.Io.net.IpAddress.listen`
        /// sets them.
        reuse_address: bool = true,
    };

    /// Listen on 127.0.0.1, on a port the kernel picks.
    pub fn open(options: Options) !LoopbackListener {
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
        return .{ .server = try address.listen(std.testing.io, .{ .reuse_address = options.reuse_address }) };
    }

    pub fn port(self: *const LoopbackListener) u16 {
        return self.server.socket.address.getPort();
    }

    /// The next connection, or null once `stop` has begun: a connection
    /// accepted then - `stop`'s own, or a client's that came as the fixture
    /// stops - is closed unanswered. Any other accept error is retried.
    pub fn accept(self: *LoopbackListener) ?std.Io.net.Stream {
        while (!self.isStopping()) {
            const stream = self.server.accept(std.testing.io) catch continue;
            if (self.isStopping()) {
                resetClose(stream);
                return null;
            }
            return stream;
        }
        return null;
    }

    /// Whether `stop` has begun: for a fixture's own loops (a held answer,
    /// a long-lived connection) that must end with the listener's.
    pub fn isStopping(self: *const LoopbackListener) bool {
        return self.stopping.load(.acquire);
    }

    /// Begin stopping: every `accept` from now returns null, and one
    /// blocked in accept() is woken by a connection of this listener's own.
    /// Then join every thread that calls `accept`, and `close`.
    pub fn stop(self: *LoopbackListener) void {
        self.stopping.store(true, .release);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(self.port()) };
        // The listener is open (`close` comes after this), so the connection
        // is taken while its backlog has room. A host out of ephemeral ports
        // (EADDRNOTAVAIL) frees them as their TIME_WAITs end - 30 s on macOS
        // - so that is retried for as long; a thread left blocked in accept()
        // would hang its join, so anything else says so at once.
        var attempt: u32 = 0;
        while (true) : (attempt += 1) {
            self.wake = address.connect(std.testing.io, .{ .mode = .stream }) catch |err| switch (err) {
                error.AddressUnavailable, error.SystemResources => {
                    if (attempt < wake_attempts) {
                        std.Io.sleep(std.testing.io, .fromMilliseconds(wake_retry_ms), .awake) catch {};
                        continue;
                    }
                    std.debug.panic("LoopbackListener.stop: cannot wake the accept thread: {t}", .{err});
                },
                else => std.debug.panic("LoopbackListener.stop: cannot wake the accept thread: {t}", .{err}),
            };
            return;
        }
    }

    /// 6,000 tries 10 ms apart: a minute, twice macOS's TIME_WAIT.
    const wake_attempts = 6000;
    const wake_retry_ms = 10;

    /// Close the listener - only after every thread that calls `accept`
    /// has been joined.
    pub fn close(self: *LoopbackListener) void {
        // A wake-up connection no thread took is reset with the listener;
        // one accept() took it reset already. Either way its own end goes
        // last, with nothing left to wait out.
        self.server.deinit(std.testing.io);
        if (self.wake) |wake| wake.close(std.testing.io);
        self.wake = null;
    }
};

/// Close `stream` with a reset (SO_LINGER 0) instead of a FIN: neither end
/// waits out a TIME_WAIT. For connections whose bytes no longer matter - a
/// wake-up, a stress test's clients.
pub fn resetClose(stream: std.Io.net.Stream) void {
    const linger: std.posix.linger = .{ .onoff = 1, .linger = 0 };
    std.posix.setsockopt(stream.socket.handle, std.posix.SOL.SOCKET, std.posix.SO.LINGER, std.mem.asBytes(&linger)) catch {};
    stream.close(std.testing.io);
}
