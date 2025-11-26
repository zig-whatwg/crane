//! Windows IOCP Backend
//!
//! High-performance I/O backend using Windows I/O Completion Ports.
//!
//! ## Features
//!
//! - Native proactor pattern (completion-based)
//! - Thread pool for concurrent completions
//! - Overlapped I/O for async operations
//! - Socket and file handle support
//!
//! ## Requirements
//!
//! - Windows Vista+ (for full IOCP support)
//! - Windows 10+ (for enhanced socket APIs)
//!
//! ## TODO(IOCP)
//!
//! This module is a stub. Full implementation requires:
//! - CreateIoCompletionPort setup
//! - OVERLAPPED structure management
//! - GetQueuedCompletionStatus/Ex polling
//! - Thread pool integration
//! - WSA socket operations
//!

const std = @import("std");
const builtin = @import("builtin");
const poller = @import("poller.zig");

pub const IOCPPoller = struct {
    allocator: std.mem.Allocator,
    pending_count: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: poller.Config) !*Self {
        _ = config;

        if (builtin.os.tag != .windows) {
            return poller.PollerError.PlatformNotSupported;
        }

        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
        };

        // TODO: Initialize IOCP
        // - CreateIoCompletionPort(INVALID_HANDLE_VALUE, NULL, 0, thread_count)
        // - Allocate OVERLAPPED pool
        // - Start worker threads

        return self;
    }

    pub fn deinit(self: *Self) void {
        // TODO: Cleanup IOCP
        // - PostQueuedCompletionStatus to wake workers
        // - CloseHandle(iocp_handle)
        // - Join worker threads
        self.allocator.destroy(self);
    }

    pub fn submit(self: *Self, op: poller.Operation, user_data: u64) poller.PollerError!void {
        _ = user_data;
        _ = op;

        // TODO: Submit operation
        // - Get OVERLAPPED from pool
        // - Associate handle with IOCP if first time
        // - ReadFile/WriteFile/WSARecv/WSASend with OVERLAPPED

        self.pending_count += 1;
    }

    pub fn poll(self: *Self, completions: []poller.Completion, timeout_ns: ?u64) poller.PollerError!usize {
        _ = self;
        _ = completions;
        _ = timeout_ns;

        // TODO: Poll for completions
        // - GetQueuedCompletionStatusEx() for batched completions
        // - Convert to Completion struct
        // - Return OVERLAPPED to pool

        return 0;
    }

    pub fn pending(self: *Self) usize {
        return self.pending_count;
    }

    // VTable for Poller interface
    pub const vtable = poller.Poller.VTable{
        .submit = submitVtable,
        .poll = pollVtable,
        .pending = pendingVtable,
        .deinit = deinitVtable,
    };

    fn submitVtable(ctx: *anyopaque, op: poller.Operation, user_data: u64) poller.PollerError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.submit(op, user_data);
    }

    fn pollVtable(ctx: *anyopaque, completions: []poller.Completion, timeout_ns: ?u64) poller.PollerError!usize {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.poll(completions, timeout_ns);
    }

    fn pendingVtable(ctx: *anyopaque) usize {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.pending();
    }

    fn deinitVtable(ctx: *anyopaque, allocator: std.mem.Allocator) void {
        _ = allocator;
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.deinit();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IOCPPoller - stub test" {
    // This test only runs on Windows
    if (builtin.os.tag != .windows) {
        return;
    }

    // TODO: Add real tests when implemented
}
