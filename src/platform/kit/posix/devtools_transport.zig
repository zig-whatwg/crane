//! The remote debugging transport over POSIX sockets and inherited pipes
//! (platform protocol 6.12, capability `devtools_transport`): a TCP listener
//! on 127.0.0.1 and its accepted connections, and the pipe pair of
//! --remote-debugging-pipe. Darwin and Linux.
//!
//! Chrome's DevToolsHttpHandler takes its listener from a
//! TCPServerSocketFactory bound to 127.0.0.1 (content/browser/devtools/
//! devtools_http_handler.cc; chrome/browser/devtools/
//! remote_debugging_server.cc), with SO_REUSEADDR as net::TCPServerSocket
//! sets it; that is what this does. Only loopback: Crane never binds another
//! address (tmp/plans/cdp-part1-design.md 2.1, "Security, as Chrome").

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");

const c = std.c;
const Error = platform.Error;

const is_darwin = builtin.os.tag.isDarwin();
const is_linux = builtin.os.tag == .linux;

/// Darwin's SO_NOSIGPIPE (<sys/socket.h>): a write to a connection whose peer
/// has gone fails with EPIPE instead of raising SIGPIPE.
const darwin_so_nosigpipe: u32 = 0x1022;
/// Linux's MSG_NOSIGNAL: the same, per send.
const send_flags: u32 = if (is_linux) 0x4000 else 0;

fn lastError() c.E {
    return @fromBackingInt(@intCast(c._errno().*));
}

fn mapError(err: c.E) Error {
    return switch (err) {
        .ADDRINUSE => error.Busy,
        .ACCES, .PERM => error.AccessDenied,
        .NOMEM, .NOBUFS => error.OutOfMemory,
        .BADF => error.NotFound,
        else => error.Io,
    };
}

fn fdOf(handle: i64) c.fd_t {
    return @intCast(handle);
}

/// 127.0.0.1 in network order.
fn loopbackAddress(port: u16) c.sockaddr.in {
    return .{
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, 0x7f000001),
    };
}

pub fn devtoolsListen(port: u16) Error!platform.DevtoolsListener {
    const fd = c.socket(c.AF.INET, c.SOCK.STREAM, 0);
    if (fd < 0) return mapError(lastError());
    errdefer _ = c.close(fd);
    setCloseOnExec(fd);

    const one: c_int = 1;
    _ = c.setsockopt(fd, c.SOL.SOCKET, c.SO.REUSEADDR, &one, @sizeOf(c_int));

    var address = loopbackAddress(port);
    if (c.bind(fd, @ptrCast(&address), @sizeOf(c.sockaddr.in)) != 0) return mapError(lastError());
    // Chrome's backlog (devtools_http_handler.cc kBackLog = 10).
    if (c.listen(fd, 10) != 0) return mapError(lastError());

    var bound: c.sockaddr.in = undefined;
    var length: c.socklen_t = @sizeOf(c.sockaddr.in);
    if (c.getsockname(fd, @ptrCast(&bound), &length) != 0) return mapError(lastError());
    return .{ .handle = fd, .port = std.mem.bigToNative(u16, bound.port) };
}

pub fn devtoolsWakeNew() Error!platform.DevtoolsWake {
    var fds: [2]c.fd_t = undefined;
    if (c.pipe(&fds) != 0) return mapError(lastError());
    setCloseOnExec(fds[0]);
    setCloseOnExec(fds[1]);
    return .{ .read = fds[0], .write = fds[1] };
}

pub fn devtoolsWake(wake: platform.DevtoolsWake) void {
    // One byte, never read: the read end stays readable, so every wait on it
    // - this one and any later one - returns at once.
    const byte = [1]u8{1};
    while (c.write(fdOf(wake.write), &byte, byte.len) < 0) {
        if (lastError() != .INTR) return;
    }
}

pub fn devtoolsWakeClose(wake: platform.DevtoolsWake) void {
    _ = c.close(fdOf(wake.read));
    _ = c.close(fdOf(wake.write));
}

/// Wait, with no timeout, until `fd` is readable (true) or `wake` was woken
/// (false; a wake wins when both are).
fn waitReadableOrWoken(fd: c.fd_t, wake: platform.DevtoolsWake) Error!bool {
    var poll_fds = [_]c.pollfd{
        .{ .fd = fd, .events = c.POLL.IN, .revents = 0 },
        .{ .fd = fdOf(wake.read), .events = c.POLL.IN, .revents = 0 },
    };
    while (true) {
        const ready = c.poll(&poll_fds, poll_fds.len, -1);
        if (ready < 0) {
            const err = lastError();
            if (err == .INTR) continue;
            return mapError(err);
        }
        if (poll_fds[1].revents != 0) return false;
        // Readable, or the peer's end closed (POLLHUP): the caller's read or
        // accept says which.
        if (poll_fds[0].revents != 0) return true;
    }
}

pub fn devtoolsAccept(listener: platform.DevtoolsListener, wake: platform.DevtoolsWake) Error!?platform.DevtoolsStream {
    const fd = fdOf(listener.handle);
    const connection = while (true) {
        if (!try waitReadableOrWoken(fd, wake)) return null;
        const accepted = c.accept(fd, null, null);
        if (accepted >= 0) break accepted;
        const err = lastError();
        // The connection went before it was taken: wait again.
        if (err == .INTR or err == .AGAIN or err == .CONNABORTED) continue;
        return mapError(err);
    };
    setCloseOnExec(connection);
    if (is_darwin) {
        const one: c_int = 1;
        _ = c.setsockopt(connection, c.SOL.SOCKET, darwin_so_nosigpipe, &one, @sizeOf(c_int));
    }
    // CDP is small request/response messages: no Nagle delay, as Chrome's
    // TCPServerSocket sets TCP_NODELAY on what it accepts.
    const one: c_int = 1;
    _ = c.setsockopt(connection, c.IPPROTO.TCP, c.TCP.NODELAY, &one, @sizeOf(c_int));
    return .{ .handle = connection };
}

pub fn devtoolsRead(stream: platform.DevtoolsStream, buffer: []u8) Error!usize {
    const fd = fdOf(stream.handle);
    while (true) {
        const n = c.read(fd, buffer.ptr, buffer.len);
        if (n >= 0) return @intCast(n);
        const err = lastError();
        if (err == .INTR) continue;
        // A shut-down or reset connection ends like a closed one.
        if (err == .CONNRESET or err == .NOTCONN or err == .PIPE) return 0;
        return mapError(err);
    }
}

pub fn devtoolsReadOrWake(stream: platform.DevtoolsStream, buffer: []u8, wake: platform.DevtoolsWake) Error!?usize {
    if (!try waitReadableOrWoken(fdOf(stream.handle), wake)) return null;
    return try devtoolsRead(stream, buffer);
}

pub fn devtoolsWrite(stream: platform.DevtoolsStream, bytes: platform.Bytes) Error!void {
    const fd = fdOf(stream.handle);
    var rest = bytes.slice();
    while (rest.len > 0) {
        const n = if (isSocket(fd)) c.send(fd, rest.ptr, rest.len, send_flags) else c.write(fd, rest.ptr, rest.len);
        if (n < 0) {
            const err = lastError();
            if (err == .INTR) continue;
            return error.Io;
        }
        rest = rest[@intCast(n)..];
    }
}

pub fn devtoolsShutdown(stream: platform.DevtoolsStream) void {
    // SHUT_RDWR ends a read blocked in another thread with 0 on both Linux
    // and Darwin. On a pipe it fails (ENOTSOCK); a pipe's reader ends when
    // its client closes its end.
    _ = c.shutdown(fdOf(stream.handle), c.SHUT.RDWR);
}

pub fn devtoolsClose(stream: platform.DevtoolsStream) void {
    _ = c.close(fdOf(stream.handle));
}

pub fn devtoolsCloseListener(listener: platform.DevtoolsListener) void {
    _ = c.close(fdOf(listener.handle));
}

pub fn devtoolsOpenInheritedPipe(read_fd: i32, write_fd: i32) Error!platform.DevtoolsPipe {
    if (c.fcntl(read_fd, c.F.GETFD) < 0) return error.NotFound;
    if (c.fcntl(write_fd, c.F.GETFD) < 0) return error.NotFound;
    setCloseOnExec(read_fd);
    setCloseOnExec(write_fd);
    return .{ .read = .{ .handle = read_fd }, .write = .{ .handle = write_fd } };
}

/// FD_CLOEXEC (<fcntl.h>): 1 on Linux and Darwin.
const fd_cloexec: c_int = 1;

fn setCloseOnExec(fd: c.fd_t) void {
    _ = c.fcntl(fd, c.F.SETFD, fd_cloexec);
}

/// Whether `fd` is a socket (send with no SIGPIPE) or a pipe (write).
fn isSocket(fd: c.fd_t) bool {
    var kind: c_int = 0;
    var length: c.socklen_t = @sizeOf(c_int);
    return c.getsockopt(fd, c.SOL.SOCKET, c.SO.TYPE, @ptrCast(&kind), &length) == 0;
}

test "devtoolsListen binds a free loopback port when asked for 0; a woken wake ends an accept with nothing to take, then and every time after" {
    const listener = try devtoolsListen(0);
    defer devtoolsCloseListener(listener);
    try std.testing.expect(listener.port != 0);
    const wake = try devtoolsWakeNew();
    defer devtoolsWakeClose(wake);
    devtoolsWake(wake);
    try std.testing.expect((try devtoolsAccept(listener, wake)) == null);
    try std.testing.expect((try devtoolsAccept(listener, wake)) == null);
}
