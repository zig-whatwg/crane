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
    const builtin = @import("builtin");
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

test {
    _ = poller;
    _ = macos_kqueue;
    // linux_uring and windows_iocp are stubs, tested separately
}
