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
//!     // start:  self.listener = try LoopbackListener.open(.{});
//!     //         thread = try std.Thread.spawn(.{}, serve, .{self});
//!     // serve:  while (self.listener.accept()) |stream| { ... }
//!     // stop:   self.listener.stop(); thread.join(); self.listener.close();
const std = @import("std");

pub const LoopbackListener = struct {
    server: std.Io.net.Server,
    stopping: std.atomic.Value(bool) = .init(false),

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
                stream.close(std.testing.io);
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
        // The listener is open (`close` comes after this), so a loopback
        // connection is taken while its backlog has room; a thread left
        // blocked in accept() would hang its join, so say so instead.
        const wake = address.connect(std.testing.io, .{ .mode = .stream }) catch |err|
            std.debug.panic("LoopbackListener.stop: cannot wake the accept thread: {t}", .{err});
        wake.close(std.testing.io);
    }

    /// Close the listener - only after every thread that calls `accept`
    /// has been joined.
    pub fn close(self: *LoopbackListener) void {
        self.server.deinit(std.testing.io);
    }
};
