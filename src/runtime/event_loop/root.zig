//! Production Event Loop
//!
//! WHATWG HTML-compliant event loop with production-grade performance characteristics.
//!
//! ## Architecture
//!
//! ```
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                        Event Loop                               │
//! ├─────────────────────────────────────────────────────────────────┤
//! │  Memory        │  I/O Polling    │  Scheduling   │  Threading  │
//! │  ─────────     │  ──────────     │  ───────────  │  ─────────  │
//! │  jemalloc      │  io_uring (L)   │  Task Queues  │  MPSC Queue │
//! │  ArenaPool     │  IOCP (W)       │  Microtasks   │  Workers    │
//! │  SlabAlloc     │  kqueue (M)     │  Timing Wheel │  Signals    │
//! └─────────────────────────────────────────────────────────────────┘
//! ```
//!
//! ## Phases
//!
//! - **Phase 0**: Foundation (storage backend, context, jemalloc setup)
//! - **Phase 1**: Core event loop (memory, I/O, scheduling, threading)
//! - **Phase 2+**: Integration with Storage/IndexedDB
//!
//! ## Usage
//!
//! ```zig
//! const event_loop = @import("event_loop");
//!
//! // Create event loop
//! var loop = try event_loop.EventLoop.init(allocator, .{});
//! defer loop.deinit();
//!
//! // Run until no more work
//! try loop.run();
//! ```
//!
//! ## Specification References
//!
//! - WHATWG HTML Living Standard §8.1.6: Event loops
//! - https://html.spec.whatwg.org/multipage/webappapis.html#event-loops
//!

const std = @import("std");

/// Memory management (jemalloc, arena pool, slab allocator)
pub const mem = @import("mem/root.zig");

/// I/O subsystem (poller, backends)
pub const io = @import("io/root.zig");

/// Task queue set (priority-based macrotask queues)
pub const task_queue = @import("task_queue.zig");
pub const TaskQueueSet = task_queue.TaskQueueSet;
pub const TaskNode = task_queue.TaskNode;
pub const TaskPriority = task_queue.TaskPriority;

/// Microtask queue (Promise reactions, MutationObserver)
pub const microtask = @import("microtask.zig");
pub const MicrotaskQueue = microtask.MicrotaskQueue;
pub const MicrotaskNode = microtask.MicrotaskNode;

/// Event loop scheduler (WHATWG processing model)
pub const scheduler = @import("scheduler.zig");
pub const Scheduler = scheduler.Scheduler;

/// Hierarchical timing wheel (O(1) timer operations)
pub const timer_wheel = @import("timer_wheel.zig");
pub const TimerWheel = timer_wheel.TimerWheel;
pub const TimerNode = timer_wheel.TimerNode;

/// Lock-free MPSC queue (thread-safe task submission)
pub const mpsc_queue = @import("mpsc_queue.zig");
pub const MpscQueue = mpsc_queue.MpscQueue;
pub const MpscNode = mpsc_queue.MpscNode;

/// Worker thread pool (blocking/CPU-bound operations)
pub const thread_pool = @import("thread_pool.zig");
pub const ThreadPool = thread_pool.ThreadPool;
pub const WorkItem = thread_pool.WorkItem;

/// Event loop configuration
pub const Config = struct {
    /// Memory configuration
    memory: struct {
        /// Use jemalloc if available (recommended for production)
        use_jemalloc: bool = true,

        /// Initial arena pool size
        arena_pool_size: usize = 8,

        /// Slab allocator block size
        slab_block_size: usize = 8192,
    } = .{},

    // TODO: Add I/O, scheduling, threading config
};

/// Event loop handle
///
/// This is a placeholder for the full event loop implementation.
/// Currently only provides memory management infrastructure.
pub const EventLoop = struct {
    allocator: std.mem.Allocator,
    config: Config,

    const Self = @This();

    /// Initialize event loop
    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Cleanup event loop
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Run event loop until no more work
    ///
    /// TODO(Phase 1): Implement full event loop processing
    pub fn run(self: *Self) !void {
        _ = self;
        // TODO: Implement event loop main loop
        // 1. Process microtask queue
        // 2. Select oldest runnable task from task queues
        // 3. Run task
        // 4. Perform microtask checkpoint
        // 5. Update rendering (if needed)
        // 6. Poll for I/O
        // 7. Process timers
        // 8. Repeat
    }

    /// Run event loop for a single iteration
    pub fn runOnce(self: *Self) !bool {
        _ = self;
        // TODO: Single iteration of event loop
        return false; // No more work
    }

    /// Post a task to the event loop
    ///
    /// TODO(Phase 1.8): Implement with task queues
    pub fn postTask(self: *Self, callback: *const fn () void) !void {
        _ = self;
        _ = callback;
        return error.NotImplemented;
    }

    /// Schedule a timer
    ///
    /// TODO(Phase 1.13-1.15): Implement with timing wheel
    pub fn setTimeout(self: *Self, callback: *const fn () void, delay_ms: u64) !u64 {
        _ = self;
        _ = callback;
        _ = delay_ms;
        return error.NotImplemented;
    }

    /// Cancel a timer
    pub fn clearTimeout(self: *Self, timer_id: u64) void {
        _ = self;
        _ = timer_id;
        // TODO: Implement
    }
};

// Re-export memory utilities
pub const getRootAllocator = mem.getRootAllocator;
pub const MemoryStats = mem.MemoryStats;
pub const getMemoryStats = mem.getStats;

// ============================================================================
// Tests
// ============================================================================

test "EventLoop initialization" {
    var loop = try EventLoop.init(std.testing.allocator, .{});
    defer loop.deinit();
}

test "memory module accessible" {
    const alloc = mem.getRootAllocator();
    const ptr = try alloc.alloc(u8, 64);
    defer alloc.free(ptr);
    try std.testing.expect(ptr.len == 64);
}

test {
    _ = mem;
    _ = io;
    _ = task_queue;
    _ = microtask;
    _ = scheduler;
    _ = timer_wheel;
    _ = mpsc_queue;
    _ = thread_pool;
}
