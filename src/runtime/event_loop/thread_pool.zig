//! Worker Thread Pool for Event Loop
//!
//! Implements a thread pool for offloading CPU-bound and blocking operations
//! from the main event loop thread.
//!
//! ## Design
//!
//! - Configurable number of worker threads
//! - Work queue using MPSC queue
//! - Completion notifications back to main loop
//! - Graceful shutdown
//! - Signal masking: worker threads inherit blocked signals
//!
//! ## Signal Handling (Phase 1.18)
//!
//! Worker threads should NOT handle signals. Before spawning workers:
//! 1. Main thread blocks all signals
//! 2. Workers inherit blocked signal mask (POSIX behavior)
//! 3. Main thread handles signals via signalfd/kqueue
//!
//! This prevents worker threads from being interrupted by signals,
//! ensuring predictable behavior and avoiding complex signal-safe code.
//!
//! ## Usage
//!
//! Main thread submits work items. Worker threads execute them and
//! post completions back to the main loop.
//!
//! ## References
//!
//! - Node.js libuv thread pool
//! - Tokio's blocking thread pool
//! - POSIX signal handling best practices

const std = @import("std");
const mpsc_queue = @import("mpsc_queue.zig");
const builtin = @import("builtin");
const posix = std.posix;

// Signal mask constants (POSIX)
const SIG_BLOCK: u32 = 1;
const SIG_SETMASK: u32 = 3;

// ============================================================================
// Signal Masking (Phase 1.18)
// ============================================================================

/// Check if signal masking is supported on this platform
const signal_masking_supported = builtin.os.tag == .linux or builtin.os.tag == .macos or
    builtin.os.tag == .freebsd or builtin.os.tag == .netbsd or builtin.os.tag == .openbsd;

/// Platform-specific signal mask storage
/// On macOS sigset_t is u32, on Linux it's a struct with __val array
pub const SignalMask = struct {
    inner: if (signal_masking_supported) posix.sigset_t else void = if (signal_masking_supported) @as(posix.sigset_t, 0) else {},
    valid: bool = false,
};

/// Block all signals on the current thread
///
/// Returns the previous signal mask for restoration.
/// On POSIX systems, uses pthread_sigmask (via sigprocmask).
pub fn blockAllSignals() !SignalMask {
    if (comptime signal_masking_supported) {
        var block_set: posix.sigset_t = 0;
        var old_set: posix.sigset_t = 0;

        // Fill the signal set (block common signals that might interrupt workers)
        const signals_to_block = [_]u8{
            posix.SIG.INT, // Ctrl+C
            posix.SIG.TERM, // Termination
            posix.SIG.HUP, // Hangup
            posix.SIG.QUIT, // Quit
            posix.SIG.USR1, // User signal 1
            posix.SIG.USR2, // User signal 2
            posix.SIG.ALRM, // Alarm
            posix.SIG.PIPE, // Broken pipe (important for I/O)
        };

        for (signals_to_block) |sig| {
            posix.sigaddset(&block_set, sig);
        }

        // Apply the mask using raw constant
        posix.sigprocmask(SIG_BLOCK, &block_set, &old_set);

        return .{ .inner = old_set, .valid = true };
    } else {
        // Unsupported platform - return empty struct
        return .{};
    }
}

/// Restore a previously saved signal mask
pub fn restoreSignalMask(mask: SignalMask) !void {
    if (comptime signal_masking_supported) {
        if (!mask.valid) return; // Nothing to restore

        var old_set: posix.sigset_t = 0;
        posix.sigprocmask(SIG_SETMASK, &mask.inner, &old_set);
    }
    // No-op on unsupported platforms
}

pub const MpscNode = mpsc_queue.MpscNode;
pub const MpscQueue = mpsc_queue.MpscQueue;

/// Work item callback type
pub const WorkCallback = *const fn (user_data: ?*anyopaque) void;

/// Completion callback type (called on main thread)
pub const CompletionCallback = *const fn (user_data: ?*anyopaque, result: ?*anyopaque) void;

/// Work item for thread pool
pub const WorkItem = struct {
    /// MPSC queue node (must be first for intrusive list)
    node: MpscNode = .{},

    /// Work function to execute on worker thread
    work_fn: WorkCallback,

    /// Completion function to call on main thread
    completion_fn: ?CompletionCallback = null,

    /// User data passed to callbacks
    user_data: ?*anyopaque = null,

    /// Result from work function (set by worker, read by main thread)
    result: ?*anyopaque = null,

    /// Initialize work item
    pub fn init(work_fn: WorkCallback, user_data: ?*anyopaque) WorkItem {
        return .{
            .work_fn = work_fn,
            .user_data = user_data,
        };
    }

    /// Initialize with completion callback
    pub fn initWithCompletion(
        work_fn: WorkCallback,
        completion_fn: CompletionCallback,
        user_data: ?*anyopaque,
    ) WorkItem {
        return .{
            .work_fn = work_fn,
            .completion_fn = completion_fn,
            .user_data = user_data,
        };
    }
};

/// Signal mask configuration for thread pool
pub const SignalConfig = struct {
    /// Block all signals on worker threads (recommended)
    block_all_signals: bool = true,

    /// Custom signal set to block (if block_all_signals is false)
    /// For POSIX systems, this would be a sigset_t
    custom_mask: ?*anyopaque = null,
};

/// Thread pool for executing blocking/CPU-bound work
pub const ThreadPool = struct {
    /// Allocator for thread management
    allocator: std.mem.Allocator,

    /// Worker threads
    workers: []std.Thread,

    /// Work queue (producers: any thread, consumer: workers)
    work_queue: MpscQueue,

    /// Completion queue (producers: workers, consumer: main thread)
    completion_queue: MpscQueue,

    /// Shutdown flag
    shutdown: std.atomic.Value(bool),

    /// Semaphore for work notification
    work_semaphore: std.Thread.Semaphore,

    /// Statistics
    total_submitted: std.atomic.Value(usize),
    total_completed: std.atomic.Value(usize),

    /// Saved signal mask (restored on deinit)
    saved_signal_mask: SignalMask = .{},

    /// Signal masking enabled
    signals_blocked: bool = false,

    const Self = @This();

    /// Initialize thread pool with default configuration
    ///
    /// Creates `thread_count` worker threads.
    /// If thread_count is 0, uses number of CPU cores.
    pub fn init(allocator: std.mem.Allocator, thread_count: usize) !*Self {
        return initWithConfig(allocator, thread_count, .{});
    }

    /// Initialize thread pool with signal configuration
    ///
    /// Creates `thread_count` worker threads with signal masking.
    /// Workers inherit blocked signals from the spawning thread.
    pub fn initWithConfig(allocator: std.mem.Allocator, thread_count: usize, config: SignalConfig) !*Self {
        const actual_count = if (thread_count == 0) blk: {
            const cpus = std.Thread.getCpuCount() catch 4;
            break :blk @min(cpus, 16); // Cap at 16 threads
        } else thread_count;

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .workers = undefined,
            .work_queue = MpscQueue.init(),
            .completion_queue = MpscQueue.init(),
            .shutdown = std.atomic.Value(bool).init(false),
            .work_semaphore = .{},
            .total_submitted = std.atomic.Value(usize).init(0),
            .total_completed = std.atomic.Value(usize).init(0),
        };

        // Phase 1.18: Block signals before spawning workers
        // Workers will inherit the blocked signal mask (POSIX behavior)
        if (config.block_all_signals) {
            self.saved_signal_mask = blockAllSignals() catch |err| blk: {
                // Non-fatal: continue without signal masking
                std.log.warn("Failed to block signals: {}", .{err});
                break :blk SignalMask{};
            };
            self.signals_blocked = true;
        }

        self.workers = try allocator.alloc(std.Thread, actual_count);
        errdefer {
            allocator.free(self.workers);
            if (self.signals_blocked) {
                restoreSignalMask(self.saved_signal_mask) catch {};
            }
        }

        // Spawn worker threads (they inherit blocked signal mask)
        var spawned: usize = 0;
        errdefer {
            self.shutdown.store(true, .release);
            for (0..spawned) |_| {
                self.work_semaphore.post();
            }
            for (self.workers[0..spawned]) |*w| {
                w.join();
            }
        }

        for (self.workers) |*worker| {
            worker.* = try std.Thread.spawn(.{}, workerLoop, .{self});
            spawned += 1;
        }

        // Restore signal mask on main thread after spawning
        // Main thread needs to handle signals
        if (self.signals_blocked) {
            restoreSignalMask(self.saved_signal_mask) catch |err| {
                std.log.warn("Failed to restore signal mask: {}", .{err});
            };
        }

        return self;
    }

    /// Shutdown thread pool and wait for workers to finish
    pub fn deinit(self: *Self) void {
        // Signal shutdown
        self.shutdown.store(true, .release);

        // Wake all workers
        for (self.workers) |_| {
            self.work_semaphore.post();
        }

        // Wait for workers to finish
        for (self.workers) |*worker| {
            worker.join();
        }

        self.allocator.free(self.workers);
        self.allocator.destroy(self);
    }

    /// Submit work to the thread pool
    ///
    /// Thread-safe: can be called from any thread.
    pub fn submit(self: *Self, work: *WorkItem) void {
        _ = self.total_submitted.fetchAdd(1, .monotonic);
        self.work_queue.push(&work.node);
        self.work_semaphore.post();
    }

    /// Poll for completed work items
    ///
    /// Returns completed work items. Call from main thread.
    /// Returns null if no completions available.
    pub fn pollCompletion(self: *Self) ?*WorkItem {
        const node = self.completion_queue.pop() orelse return null;
        return @fieldParentPtr("node", node);
    }

    /// Get number of worker threads
    pub fn workerCount(self: *const Self) usize {
        return self.workers.len;
    }

    /// Get statistics
    pub const Stats = struct {
        worker_count: usize,
        total_submitted: usize,
        total_completed: usize,
    };

    pub fn getStats(self: *const Self) Stats {
        return .{
            .worker_count = self.workers.len,
            .total_submitted = self.total_submitted.load(.monotonic),
            .total_completed = self.total_completed.load(.monotonic),
        };
    }

    /// Worker thread main loop
    fn workerLoop(self: *Self) void {
        while (true) {
            // Wait for work
            self.work_semaphore.wait();

            // Check shutdown
            if (self.shutdown.load(.acquire)) {
                break;
            }

            // Get work item
            const node = self.work_queue.pop() orelse continue;
            const work: *WorkItem = @fieldParentPtr("node", node);

            // Execute work
            work.work_fn(work.user_data);

            // Post completion if callback provided
            if (work.completion_fn != null) {
                _ = self.total_completed.fetchAdd(1, .monotonic);
                self.completion_queue.push(&work.node);
            } else {
                _ = self.total_completed.fetchAdd(1, .monotonic);
            }
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ThreadPool - basic work submission" {
    var pool = try ThreadPool.init(std.testing.allocator, 2);
    defer pool.deinit();

    try std.testing.expectEqual(@as(usize, 2), pool.workerCount());

    var executed = std.atomic.Value(bool).init(false);
    var work = WorkItem.init(setAtomicFlagCallback, &executed);

    pool.submit(&work);

    // Wait for completion
    while (!executed.load(.acquire)) {
        std.Thread.yield() catch {};
    }

    try std.testing.expect(executed.load(.acquire));
}

test "ThreadPool - completion callback" {
    var pool = try ThreadPool.init(std.testing.allocator, 1);
    defer pool.deinit();

    var completed = std.atomic.Value(bool).init(false);
    var work = WorkItem.initWithCompletion(
        noopWorkCallback,
        completionFlagCallback,
        &completed,
    );

    pool.submit(&work);

    // Poll for completion
    var attempts: usize = 0;
    while (attempts < 1000) : (attempts += 1) {
        if (pool.pollCompletion()) |w| {
            if (w.completion_fn) |cb| {
                cb(w.user_data, w.result);
            }
            break;
        }
        std.Thread.yield() catch {};
    }

    try std.testing.expect(completed.load(.acquire));
}

test "ThreadPool - multiple work items" {
    var pool = try ThreadPool.init(std.testing.allocator, 4);
    defer pool.deinit();

    var counter = std.atomic.Value(usize).init(0);
    var works: [10]WorkItem = undefined;

    for (&works) |*w| {
        w.* = WorkItem.init(incrementCallback, &counter);
        pool.submit(w);
    }

    // Wait for all to complete
    while (counter.load(.acquire) < 10) {
        std.Thread.yield() catch {};
    }

    try std.testing.expectEqual(@as(usize, 10), counter.load(.acquire));
}

test "ThreadPool - statistics" {
    var pool = try ThreadPool.init(std.testing.allocator, 2);
    defer pool.deinit();

    var dummy: usize = 0;
    var work = WorkItem.init(incrementCallback, &dummy);

    pool.submit(&work);

    // Wait for completion
    while (pool.getStats().total_completed < 1) {
        std.Thread.yield() catch {};
    }

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.worker_count);
    try std.testing.expectEqual(@as(usize, 1), stats.total_submitted);
    try std.testing.expectEqual(@as(usize, 1), stats.total_completed);
}

// Test helpers

fn setAtomicFlagCallback(user_data: ?*anyopaque) void {
    const flag: *std.atomic.Value(bool) = @ptrCast(@alignCast(user_data.?));
    flag.store(true, .release);
}

fn noopWorkCallback(_: ?*anyopaque) void {}

fn completionFlagCallback(user_data: ?*anyopaque, _: ?*anyopaque) void {
    const flag: *std.atomic.Value(bool) = @ptrCast(@alignCast(user_data.?));
    flag.store(true, .release);
}

fn incrementCallback(user_data: ?*anyopaque) void {
    const counter: *std.atomic.Value(usize) = @ptrCast(@alignCast(user_data.?));
    _ = counter.fetchAdd(1, .acq_rel);
}
