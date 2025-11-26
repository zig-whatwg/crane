//! Unified I/O Poller Interface
//!
//! This module provides a platform-agnostic completion-based I/O interface that
//! abstracts the differences between io_uring (Linux), IOCP (Windows), and kqueue (macOS).
//!
//! ## Design Philosophy
//!
//! The interface follows the **Proactor pattern** - operations are submitted asynchronously
//! and completions are collected when ready. This maps naturally to:
//! - io_uring: Native proactor (SQPOLL mode)
//! - IOCP: Native proactor
//! - kqueue: Simulated proactor (reactor + thread pool)
//!
//! ## Usage
//!
//! ```zig
//! var poller = try Poller.init(allocator, .{});
//! defer poller.deinit();
//!
//! // Submit a read operation
//! try poller.submit(.{
//!     .Read = .{
//!         .fd = socket_fd,
//!         .buffer = buffer,
//!         .offset = 0,
//!     },
//! }, user_data);
//!
//! // Poll for completions
//! var completions: [64]Completion = undefined;
//! const count = try poller.poll(&completions, timeout_ns);
//!
//! for (completions[0..count]) |completion| {
//!     // Handle completion
//! }
//! ```
//!
//! ## Platform-Specific Backends
//!
//! - Linux: io_uring with SQPOLL for kernel-side polling
//! - Windows: IOCP (I/O Completion Ports)
//! - macOS: kqueue + simulated proactor via thread pool
//!
//! ## TODO(Poller)
//!
//! - Implement Linux io_uring backend (Phase 1.4)
//! - Implement Windows IOCP backend (Phase 1.5)
//! - Implement macOS kqueue backend (Phase 1.6)
//!

const std = @import("std");
const builtin = @import("builtin");

// ============================================================================
// Types
// ============================================================================

/// I/O operation types
pub const Operation = union(enum) {
    /// Read data from file descriptor
    Read: ReadOp,

    /// Write data to file descriptor
    Write: WriteOp,

    /// Accept connection on listening socket
    Accept: AcceptOp,

    /// Connect to remote address
    Connect: ConnectOp,

    /// Close file descriptor
    Close: CloseOp,

    /// Send datagram (UDP)
    SendTo: SendToOp,

    /// Receive datagram (UDP)
    RecvFrom: RecvFromOp,

    /// Timeout (for timers)
    Timeout: TimeoutOp,

    /// Cancel a pending operation
    Cancel: CancelOp,

    /// No-op (for waking up the event loop)
    Nop: void,
};

/// Read operation
pub const ReadOp = struct {
    fd: std.posix.fd_t,
    buffer: []u8,
    offset: u64 = 0,
};

/// Write operation
pub const WriteOp = struct {
    fd: std.posix.fd_t,
    buffer: []const u8,
    offset: u64 = 0,
};

/// Accept operation
pub const AcceptOp = struct {
    listen_fd: std.posix.fd_t,
};

/// Connect operation
pub const ConnectOp = struct {
    fd: std.posix.fd_t,
    address: std.net.Address,
};

/// Close operation
pub const CloseOp = struct {
    fd: std.posix.fd_t,
};

/// Send datagram operation
pub const SendToOp = struct {
    fd: std.posix.fd_t,
    buffer: []const u8,
    address: std.net.Address,
};

/// Receive datagram operation
pub const RecvFromOp = struct {
    fd: std.posix.fd_t,
    buffer: []u8,
};

/// Timeout operation
pub const TimeoutOp = struct {
    /// Timeout in nanoseconds
    timeout_ns: u64,
};

/// Cancel operation
pub const CancelOp = struct {
    /// User data of operation to cancel
    target_user_data: u64,
};

/// Completion result
pub const CompletionResult = union(enum) {
    /// Operation succeeded
    /// Value depends on operation type:
    /// - Read/Write: bytes transferred
    /// - Accept: new file descriptor
    /// - Connect/Close: 0
    Success: usize,

    /// Operation failed
    Error: PollerError,

    /// Operation was cancelled
    Cancelled: void,
};

/// Completion event
pub const Completion = struct {
    /// The completed operation
    operation: Operation,

    /// Result of the operation
    result: CompletionResult,

    /// User-provided context
    user_data: u64,
};

/// Poller errors
pub const PollerError = error{
    /// File descriptor is invalid
    BadFd,

    /// Operation would block (non-blocking mode)
    WouldBlock,

    /// Connection refused
    ConnectionRefused,

    /// Connection reset by peer
    ConnectionReset,

    /// Network is unreachable
    NetworkUnreachable,

    /// Address already in use
    AddressInUse,

    /// Operation timed out
    TimedOut,

    /// Operation was cancelled
    Cancelled,

    /// Permission denied
    PermissionDenied,

    /// No buffer space available
    NoBufferSpace,

    /// Too many open files
    TooManyOpenFiles,

    /// Out of memory
    OutOfMemory,

    /// Submission queue full
    SubmissionQueueFull,

    /// System call interrupted
    Interrupted,

    /// Generic I/O error
    IoError,

    /// Platform not supported
    PlatformNotSupported,

    /// Backend not initialized
    NotInitialized,
};

/// Poller configuration
pub const Config = struct {
    /// Submission queue size (power of 2, default 256)
    submission_queue_size: u32 = 256,

    /// Completion queue size (power of 2, default 512)
    completion_queue_size: u32 = 512,

    /// Enable kernel-side polling (io_uring SQPOLL, requires CAP_SYS_NICE)
    kernel_poll: bool = false,

    /// Thread pool size for simulated proactor (kqueue)
    thread_pool_size: u32 = 4,
};

// ============================================================================
// Poller Interface
// ============================================================================

/// Unified I/O poller interface
///
/// Provides platform-agnostic completion-based I/O operations.
/// Selects the best backend for the current platform at compile time.
pub const Poller = struct {
    /// Opaque pointer to backend implementation
    ptr: *anyopaque,

    /// Virtual function table
    vtable: *const VTable,

    /// Allocator used for this poller
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Virtual function table for poller backends
    pub const VTable = struct {
        /// Submit an I/O operation
        submit: *const fn (ctx: *anyopaque, op: Operation, user_data: u64) PollerError!void,

        /// Poll for completions
        /// Returns number of completions, or error
        poll: *const fn (ctx: *anyopaque, completions: []Completion, timeout_ns: ?u64) PollerError!usize,

        /// Get number of pending operations
        pending: *const fn (ctx: *anyopaque) usize,

        /// Deinitialize backend
        deinit: *const fn (ctx: *anyopaque, allocator: std.mem.Allocator) void,
    };

    /// Initialize poller with platform-appropriate backend
    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        _ = config;

        // For now, return a mock poller
        // TODO: Implement platform-specific backends
        const MockPoller = struct {
            pending_count: usize = 0,

            fn submitFn(ctx: *anyopaque, op: Operation, user_data: u64) PollerError!void {
                _ = op;
                _ = user_data;
                const self: *@This() = @ptrCast(@alignCast(ctx));
                self.pending_count += 1;
            }

            fn pollFn(ctx: *anyopaque, completions: []Completion, timeout_ns: ?u64) PollerError!usize {
                _ = ctx;
                _ = completions;
                _ = timeout_ns;
                return 0; // No completions in mock
            }

            fn pendingFn(ctx: *anyopaque) usize {
                const self: *@This() = @ptrCast(@alignCast(ctx));
                return self.pending_count;
            }

            fn deinitFn(ctx: *anyopaque, alloc: std.mem.Allocator) void {
                const self: *@This() = @ptrCast(@alignCast(ctx));
                alloc.destroy(self);
            }

            const vtable = VTable{
                .submit = submitFn,
                .poll = pollFn,
                .pending = pendingFn,
                .deinit = deinitFn,
            };
        };

        const impl = try allocator.create(MockPoller);
        impl.* = .{};

        return Self{
            .ptr = impl,
            .vtable = &MockPoller.vtable,
            .allocator = allocator,
        };
    }

    /// Deinitialize poller
    pub fn deinit(self: *Self) void {
        self.vtable.deinit(self.ptr, self.allocator);
    }

    /// Submit an I/O operation
    ///
    /// The operation is queued for execution. Use `poll()` to retrieve
    /// the completion when the operation finishes.
    pub fn submit(self: *Self, op: Operation, user_data: u64) PollerError!void {
        return self.vtable.submit(self.ptr, op, user_data);
    }

    /// Poll for completions
    ///
    /// Returns the number of completions written to the buffer.
    /// - `timeout_ns = null`: Block until at least one completion
    /// - `timeout_ns = 0`: Non-blocking poll
    /// - `timeout_ns = N`: Wait up to N nanoseconds
    pub fn poll(self: *Self, completions: []Completion, timeout_ns: ?u64) PollerError!usize {
        return self.vtable.poll(self.ptr, completions, timeout_ns);
    }

    /// Get number of pending operations
    pub fn pending(self: *Self) usize {
        return self.vtable.pending(self.ptr);
    }

    /// Submit a read operation
    pub fn submitRead(self: *Self, fd: std.posix.fd_t, buffer: []u8, offset: u64, user_data: u64) PollerError!void {
        return self.submit(.{
            .Read = .{
                .fd = fd,
                .buffer = buffer,
                .offset = offset,
            },
        }, user_data);
    }

    /// Submit a write operation
    pub fn submitWrite(self: *Self, fd: std.posix.fd_t, buffer: []const u8, offset: u64, user_data: u64) PollerError!void {
        return self.submit(.{
            .Write = .{
                .fd = fd,
                .buffer = buffer,
                .offset = offset,
            },
        }, user_data);
    }

    /// Submit an accept operation
    pub fn submitAccept(self: *Self, listen_fd: std.posix.fd_t, user_data: u64) PollerError!void {
        return self.submit(.{
            .Accept = .{
                .listen_fd = listen_fd,
            },
        }, user_data);
    }

    /// Submit a connect operation
    pub fn submitConnect(self: *Self, fd: std.posix.fd_t, address: std.net.Address, user_data: u64) PollerError!void {
        return self.submit(.{
            .Connect = .{
                .fd = fd,
                .address = address,
            },
        }, user_data);
    }

    /// Submit a close operation
    pub fn submitClose(self: *Self, fd: std.posix.fd_t, user_data: u64) PollerError!void {
        return self.submit(.{
            .Close = .{
                .fd = fd,
            },
        }, user_data);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Poller - initialization" {
    var poller = try Poller.init(std.testing.allocator, .{});
    defer poller.deinit();
}

test "Poller - submit read" {
    var poller = try Poller.init(std.testing.allocator, .{});
    defer poller.deinit();

    var buffer: [1024]u8 = undefined;
    try poller.submitRead(0, &buffer, 0, 42);

    try std.testing.expectEqual(@as(usize, 1), poller.pending());
}

test "Poller - poll returns zero in mock" {
    var poller = try Poller.init(std.testing.allocator, .{});
    defer poller.deinit();

    var completions: [64]Completion = undefined;
    const count = try poller.poll(&completions, 0);

    try std.testing.expectEqual(@as(usize, 0), count);
}
