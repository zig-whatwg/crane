//! Linux io_uring Backend
//!
//! High-performance I/O backend using Linux io_uring with SQPOLL mode
//! for kernel-side submission queue polling.
//!
//! ## Features
//!
//! - Zero-copy I/O with registered buffers
//! - Kernel-side polling (SQPOLL) for lowest latency
//! - Batched submission and completion
//! - Direct file descriptors (registered fds)
//!
//! ## Requirements
//!
//! - Linux kernel 5.4+ (basic io_uring)
//! - Linux kernel 5.11+ (for SQPOLL without CAP_SYS_NICE)
//! - Linux kernel 5.19+ (for all advanced features)
//!
//! ## TODO(io_uring)
//!
//! This module is a stub. Full implementation requires:
//! - io_uring setup with liburing or direct syscalls
//! - SQE/CQE ring buffer management
//! - SQPOLL mode configuration
//! - Buffer registration
//! - Linked operations
//!

const std = @import("std");
const builtin = @import("builtin");
const poller = @import("poller.zig");

pub const UringPoller = struct {
    allocator: std.mem.Allocator,
    pending_count: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: poller.Config) !*Self {
        _ = config;

        if (builtin.os.tag != .linux) {
            return poller.PollerError.PlatformNotSupported;
        }

        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
        };

        // TODO: Initialize io_uring
        // - io_uring_setup() syscall
        // - mmap SQ and CQ rings
        // - Configure SQPOLL if requested

        return self;
    }

    pub fn deinit(self: *Self) void {
        // TODO: Cleanup io_uring
        // - io_uring_queue_exit()
        // - munmap rings
        self.allocator.destroy(self);
    }

    pub fn submit(self: *Self, op: poller.Operation, user_data: u64) poller.PollerError!void {
        _ = user_data;
        _ = op;

        // TODO: Submit operation to SQ
        // - Get SQE from ring
        // - Fill based on operation type
        // - io_uring_submit() if not using SQPOLL

        self.pending_count += 1;
    }

    pub fn poll(self: *Self, completions: []poller.Completion, timeout_ns: ?u64) poller.PollerError!usize {
        _ = self;
        _ = completions;
        _ = timeout_ns;

        // TODO: Poll CQ for completions
        // - io_uring_peek_cqe() or io_uring_wait_cqe()
        // - Convert CQE to Completion
        // - io_uring_cqe_seen() to advance ring

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

test "UringPoller - stub test" {
    // This test only runs on Linux
    if (builtin.os.tag != .linux) {
        return;
    }

    // TODO: Add real tests when implemented
}
