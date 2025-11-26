//! I/O Subsystem
//!
//! Platform-agnostic I/O poller and related utilities.
//!
//! ## Backends
//!
//! - **Linux**: io_uring with SQPOLL (Phase 1.4)
//! - **Windows**: IOCP (Phase 1.5)
//! - **macOS**: kqueue + simulated proactor (Phase 1.6)
//!

const std = @import("std");
const builtin = @import("builtin");

/// Unified poller interface
pub const poller = @import("poller.zig");
pub const Poller = poller.Poller;
pub const PollerConfig = poller.Config;
pub const PollerError = poller.PollerError;
pub const Operation = poller.Operation;
pub const Completion = poller.Completion;
pub const CompletionResult = poller.CompletionResult;

// Re-export operation types
pub const ReadOp = poller.ReadOp;
pub const WriteOp = poller.WriteOp;
pub const AcceptOp = poller.AcceptOp;
pub const ConnectOp = poller.ConnectOp;
pub const CloseOp = poller.CloseOp;

// Platform-specific backends (stubs - to be fully implemented)
pub const linux_uring = @import("linux_uring.zig");
pub const windows_iocp = @import("windows_iocp.zig");
pub const macos_kqueue = @import("macos_kqueue.zig");

/// Get the platform-native poller type
pub fn NativePoller() type {
    return switch (builtin.os.tag) {
        .linux => linux_uring.IoUringPoller,
        .windows => windows_iocp.IocpPoller,
        .macos, .freebsd, .ios => macos_kqueue.KqueuePoller,
        else => @compileError("Unsupported platform for I/O polling"),
    };
}

// ============================================================================
// Tests
// ============================================================================

const posix = std.posix;

test {
    _ = poller;
    _ = macos_kqueue;
    // linux_uring and windows_iocp are stubs, tested separately
}

// ============================================================================
// Integration Tests
// ============================================================================

fn createPipe() !struct { read_fd: posix.fd_t, write_fd: posix.fd_t } {
    const fds = try posix.pipe();
    return .{ .read_fd = fds[0], .write_fd = fds[1] };
}

fn closePipe(read_fd: posix.fd_t, write_fd: posix.fd_t) void {
    posix.close(read_fd);
    posix.close(write_fd);
}

fn skipIfNotSupported() bool {
    // Only run on macOS for now (kqueue is functional)
    // Linux and Windows backends are stubs
    return builtin.os.tag != .macos and builtin.os.tag != .freebsd;
}

test "integration - timeout fires correctly" {
    if (skipIfNotSupported()) return;

    const Native = NativePoller();
    var native_poller = try Native.init(std.testing.allocator, .{});
    defer native_poller.deinit();

    // Submit a 10ms timeout
    const timeout_ns: u64 = 10_000_000; // 10ms
    try native_poller.submit(.{ .Timeout = .{ .timeout_ns = timeout_ns } }, 1);

    const start = std.time.nanoTimestamp();

    // Poll with 1 second max wait
    var completions: [16]Completion = undefined;
    const count = try native_poller.poll(&completions, 1_000_000_000);

    const elapsed = std.time.nanoTimestamp() - start;

    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqual(@as(u64, 1), completions[0].user_data);
    try std.testing.expect(completions[0].result == .Success);

    // Verify timeout fired within reasonable bounds (5ms - 100ms)
    try std.testing.expect(elapsed >= 5_000_000);
    try std.testing.expect(elapsed < 100_000_000);
}

test "integration - multiple timeouts" {
    if (skipIfNotSupported()) return;

    const Native = NativePoller();
    var native_poller = try Native.init(std.testing.allocator, .{});
    defer native_poller.deinit();

    // Submit 3 timeouts with different durations
    try native_poller.submit(.{ .Timeout = .{ .timeout_ns = 5_000_000 } }, 1); // 5ms
    try native_poller.submit(.{ .Timeout = .{ .timeout_ns = 10_000_000 } }, 2); // 10ms
    try native_poller.submit(.{ .Timeout = .{ .timeout_ns = 15_000_000 } }, 3); // 15ms

    try std.testing.expectEqual(@as(usize, 3), native_poller.pending());

    // Collect all completions
    var completions: [16]Completion = undefined;
    var total_count: usize = 0;

    // Poll multiple times to collect all
    while (native_poller.pending() > 0) {
        var buf: [16]Completion = undefined;
        const count = try native_poller.poll(&buf, 100_000_000);
        for (buf[0..count]) |c| {
            completions[total_count] = c;
            total_count += 1;
        }
    }

    try std.testing.expectEqual(@as(usize, 3), total_count);

    // All should complete successfully
    for (completions[0..total_count]) |completion| {
        try std.testing.expect(completion.result == .Success);
    }
}

test "integration - pipe read/write" {
    if (skipIfNotSupported()) return;

    const Native = NativePoller();
    var native_poller = try Native.init(std.testing.allocator, .{});
    defer native_poller.deinit();

    // Create a pipe
    const pipe = try createPipe();
    defer closePipe(pipe.read_fd, pipe.write_fd);

    // Write data to pipe (synchronous for simplicity)
    const message = "Hello, poller!";
    _ = try posix.write(pipe.write_fd, message);

    // Submit async read
    var read_buffer: [64]u8 = undefined;
    try native_poller.submit(.{
        .Read = .{
            .fd = pipe.read_fd,
            .buffer = &read_buffer,
            .offset = 0,
        },
    }, 42);

    // Poll for completion
    var completions: [16]Completion = undefined;
    const count = try native_poller.poll(&completions, 100_000_000);

    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqual(@as(u64, 42), completions[0].user_data);

    switch (completions[0].result) {
        .Success => |bytes_read| {
            try std.testing.expectEqual(message.len, bytes_read);
            try std.testing.expectEqualStrings(message, read_buffer[0..bytes_read]);
        },
        .Error => |err| {
            std.debug.print("Read failed: {}\n", .{err});
            return error.TestUnexpectedResult;
        },
        .Cancelled => return error.TestUnexpectedResult,
    }
}

test "integration - async write then read" {
    if (skipIfNotSupported()) return;

    const Native = NativePoller();
    var native_poller = try Native.init(std.testing.allocator, .{});
    defer native_poller.deinit();

    // Create a pipe
    const pipe = try createPipe();
    defer closePipe(pipe.read_fd, pipe.write_fd);

    // Submit async write
    const message = "Async I/O works!";
    try native_poller.submit(.{
        .Write = .{
            .fd = pipe.write_fd,
            .buffer = message,
            .offset = 0,
        },
    }, 1);

    // Poll for write completion
    var completions: [16]Completion = undefined;
    var count = try native_poller.poll(&completions, 100_000_000);
    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expect(completions[0].result == .Success);

    // Submit async read
    var read_buffer: [64]u8 = undefined;
    try native_poller.submit(.{
        .Read = .{
            .fd = pipe.read_fd,
            .buffer = &read_buffer,
            .offset = 0,
        },
    }, 2);

    // Poll for read completion
    count = try native_poller.poll(&completions, 100_000_000);
    try std.testing.expectEqual(@as(usize, 1), count);

    switch (completions[0].result) {
        .Success => |bytes_read| {
            try std.testing.expectEqualStrings(message, read_buffer[0..bytes_read]);
        },
        .Error, .Cancelled => return error.TestUnexpectedResult,
    }
}

test "integration - poll with zero timeout returns immediately" {
    if (skipIfNotSupported()) return;

    const Native = NativePoller();
    var native_poller = try Native.init(std.testing.allocator, .{});
    defer native_poller.deinit();

    const start = std.time.nanoTimestamp();

    // Poll with zero timeout (non-blocking)
    var completions: [16]Completion = undefined;
    const count = try native_poller.poll(&completions, 0);

    const elapsed = std.time.nanoTimestamp() - start;

    // Should return immediately with 0 completions
    try std.testing.expectEqual(@as(usize, 0), count);

    // Should complete in < 10ms (allowing for system jitter)
    try std.testing.expect(elapsed < 10_000_000);
}

test "integration - vtable interface works" {
    if (skipIfNotSupported()) return;

    const Native = NativePoller();
    var native_poller = try Native.init(std.testing.allocator, .{});
    defer native_poller.deinit();

    // Create a Poller interface from the native poller
    var abstract_poller = Poller{
        .vtable = &Native.vtable,
        .ptr = native_poller,
        .allocator = std.testing.allocator,
    };

    // Use through abstract interface
    try abstract_poller.submit(.{ .Timeout = .{ .timeout_ns = 5_000_000 } }, 99);

    try std.testing.expectEqual(@as(usize, 1), abstract_poller.pending());

    var completions: [16]Completion = undefined;
    const count = try abstract_poller.poll(&completions, 100_000_000);

    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqual(@as(u64, 99), completions[0].user_data);
}

test "integration - read from closed fd" {
    if (skipIfNotSupported()) return;

    const Native = NativePoller();
    var native_poller = try Native.init(std.testing.allocator, .{});
    defer native_poller.deinit();

    // Create and immediately close pipe
    const pipe = try createPipe();
    posix.close(pipe.write_fd);

    // Read from pipe with closed write end (should return 0 bytes / EOF)
    var read_buffer: [64]u8 = undefined;
    try native_poller.submit(.{
        .Read = .{
            .fd = pipe.read_fd,
            .buffer = &read_buffer,
            .offset = 0,
        },
    }, 1);

    var completions: [16]Completion = undefined;
    const count = try native_poller.poll(&completions, 100_000_000);

    try std.testing.expectEqual(@as(usize, 1), count);

    // Should complete (either with 0 bytes or error)
    switch (completions[0].result) {
        .Success => |bytes| {
            // EOF is 0 bytes
            try std.testing.expectEqual(@as(usize, 0), bytes);
        },
        .Error, .Cancelled => {
            // Also acceptable (EBADF or similar)
        },
    }

    posix.close(pipe.read_fd);
}
