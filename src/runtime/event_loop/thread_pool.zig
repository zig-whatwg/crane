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

const std = @import("std");
const mpsc_queue = @import("mpsc_queue.zig");

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

    const Self = @This();

    /// Initialize thread pool
    ///
    /// Creates `thread_count` worker threads.
    /// If thread_count is 0, uses number of CPU cores.
    pub fn init(allocator: std.mem.Allocator, thread_count: usize) !*Self {
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

        self.workers = try allocator.alloc(std.Thread, actual_count);
        errdefer allocator.free(self.workers);

        // Spawn worker threads
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
