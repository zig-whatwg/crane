//! kit/curl: the network behind the protocol (docs/platform-protocol.md 6.7) -
//! libcurl + mbedTLS, for any platform to use.
//!
//! Step 0 of the platform protocol: the event-loop port is real (its wait
//! blocks until the deadline or a wake from any thread, with no busy loop),
//! but transfers and WebSockets still run in src/fetch/network and
//! src/websocket, which recipes step 2 moves here. Until then nothing calls
//! these operations, and starting a transfer or a socket through the
//! protocol answers `error.NetworkError` (TODO(platform step 2)). This module
//! links no C library yet; libcurl stays linked into `fetch`.

const std = @import("std");
const platform = @import("platform");

const Port = struct {
    allocator: std.mem.Allocator,
    /// Bumped by every wake; a wait sleeps only while it is unchanged.
    wake: std.atomic.Value(u32) = .init(0),
    /// Set by a wake, consumed by the next wait: a wake that comes before the
    /// wait still ends it (TaskSink posts, then wakes, from another thread).
    pending: std.atomic.Value(u32) = .init(0),
};

fn portOf(port: *platform.EventLoopPort) *Port {
    return @ptrCast(@alignCast(port));
}

/// The futex calls' Io: a futex wait and wake are plain system calls on an
/// address (src/runtime/task_sink.zig's futexIo, for the same reason).
fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// A port for `browser`'s network context. The context itself (connections,
/// DNS, TLS sessions) is still process-global in src/fetch/network until
/// recipes step 2b.
pub fn createEventLoopPort(allocator: std.mem.Allocator, browser: *platform.BrowserPlatform) platform.Error!*platform.EventLoopPort {
    _ = browser;
    const port = try allocator.create(Port);
    port.* = .{ .allocator = allocator };
    return @ptrCast(port);
}

pub fn destroyEventLoopPort(handle: *platform.EventLoopPort) void {
    const port = portOf(handle);
    port.allocator.destroy(port);
}

/// No transfer runs through the port yet, so a step runs nothing.
pub fn pollEventLoopPort(handle: *platform.EventLoopPort) bool {
    _ = handle;
    return false;
}

/// Block until `deadline` or a wake - including a wake since the last wait.
/// Spurious returns are allowed: the event loop asks again.
pub fn waitEventLoopPort(handle: *platform.EventLoopPort, deadline: ?platform.Instant) void {
    const port = portOf(handle);
    const seen = port.wake.load(.acquire);
    if (port.pending.swap(0, .acq_rel) != 0) return;
    defer _ = port.pending.swap(0, .acq_rel);
    const timeout: std.Io.Timeout = if (deadline) |at| blk: {
        const now = platform.monotonicNow().ns;
        if (at.ns <= now) return;
        break :blk .{ .duration = .{ .raw = .fromNanoseconds(at.ns - now), .clock = .awake } };
    } else .none;
    futexIo().futexWaitTimeout(u32, &port.wake.raw, seen, timeout) catch {};
}

/// Any thread.
pub fn wakeEventLoopPort(handle: *platform.EventLoopPort) void {
    const port = portOf(handle);
    port.pending.store(1, .release);
    _ = port.wake.fetchAdd(1, .release);
    futexIo().futexWake(u32, &port.wake.raw, 1);
}

/// TODO(platform step 2): libcurl moves behind the port.
pub fn startTransfer(handle: *platform.EventLoopPort, allocator: std.mem.Allocator, request: *const platform.HttpRequest, client: platform.TransferClient) platform.HttpError!*platform.Transfer {
    _ = .{ handle, allocator, request, client };
    return error.NetworkError;
}

pub fn cancelTransfer(handle: *platform.EventLoopPort, transfer: *platform.Transfer) void {
    _ = .{ handle, transfer };
}

pub fn pauseTransfer(handle: *platform.EventLoopPort, transfer: *platform.Transfer) void {
    _ = .{ handle, transfer };
}

pub fn resumeTransfer(handle: *platform.EventLoopPort, transfer: *platform.Transfer) void {
    _ = .{ handle, transfer };
}

/// TODO(platform step 2): src/websocket's curl backend moves behind the port.
pub fn openWebSocket(handle: *platform.EventLoopPort, allocator: std.mem.Allocator, request: *const platform.WebSocketRequest, client: platform.WebSocketClient) platform.HttpError!*platform.WebSocket {
    _ = .{ handle, allocator, request, client };
    return error.NetworkError;
}

pub fn sendWebSocketFrame(socket: *platform.WebSocket, kind: platform.WebSocketFrameKind, bytes: platform.Bytes) platform.HttpError!void {
    _ = .{ socket, kind, bytes };
    return error.NetworkError;
}

pub fn closeWebSocket(socket: *platform.WebSocket, code: u16, reason: platform.Str) void {
    _ = .{ socket, code, reason };
}

pub fn releaseWebSocket(socket: *platform.WebSocket) void {
    _ = socket;
}
