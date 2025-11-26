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

// TODO(Phase 1.4): io_uring backend
// pub const linux_uring = @import("linux_uring.zig");

// TODO(Phase 1.5): IOCP backend
// pub const windows_iocp = @import("windows_iocp.zig");

// TODO(Phase 1.6): kqueue backend
// pub const macos_kqueue = @import("macos_kqueue.zig");

// ============================================================================
// Tests
// ============================================================================

test {
    _ = poller;
}
