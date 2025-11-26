//! WHATWG Event Loop Scheduler
//!
//! Implements the event loop processing model as defined in the WHATWG HTML Standard.
//! The scheduler coordinates task queues, microtasks, I/O polling, and timers.
//!
//! ## Processing Model (WHATWG HTML Standard)
//!
//! 1. Select oldest macrotask from task queue set
//! 2. Execute ONE macrotask
//! 3. Perform microtask checkpoint (drain microtask queue)
//! 4. Update rendering (if applicable)
//! 5. Wait for I/O or timer (poll)
//! 6. Repeat
//!
//! ## Thread-Safe Task Posting (Phase 1.20)
//!
//! Any thread can post tasks to the main event loop using postTaskFromAnyThread().
//! Tasks are queued in a lock-free MPSC queue and processed during each tick.
//!
//! ## Work Submission Flow (Phase 1.19)
//!
//! Main loop submits work to thread pool, polls for completions, and converts
//! completions to macrotasks.
//!
//! ## References
//!
//! - WHATWG HTML Standard: Event loop processing model
//! - https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model

const std = @import("std");
const task_queue = @import("task_queue.zig");
const microtask = @import("microtask.zig");
const thread_pool = @import("thread_pool.zig");
const mpsc_queue = @import("mpsc_queue.zig");

pub const TaskQueueSet = task_queue.TaskQueueSet;
pub const TaskNode = task_queue.TaskNode;
pub const TaskPriority = task_queue.TaskPriority;
pub const TaskCallback = task_queue.TaskCallback;

pub const MicrotaskQueue = microtask.MicrotaskQueue;
pub const MicrotaskNode = microtask.MicrotaskNode;
pub const MicrotaskCallback = microtask.MicrotaskCallback;

pub const ThreadPool = thread_pool.ThreadPool;
pub const WorkItem = thread_pool.WorkItem;
pub const MpscQueue = mpsc_queue.MpscQueue;
pub const MpscNode = mpsc_queue.MpscNode;

/// Cross-thread task node for posting tasks from any thread
/// Wraps a TaskNode with MPSC queue linkage
pub const CrossThreadTask = struct {
    /// MPSC queue node (must be first for intrusive list)
    mpsc_node: MpscNode = .{},

    /// The actual task
    task: TaskNode,

    /// Priority for the task
    priority: TaskPriority,

    /// Create a cross-thread task
    pub fn init(callback: TaskCallback, user_data: ?*anyopaque, priority: TaskPriority) CrossThreadTask {
        return .{
            .task = TaskNode.init(callback, user_data, priority),
            .priority = priority,
        };
    }
};

/// Event loop scheduler state
pub const Scheduler = struct {
    /// Task queue set (macrotasks)
    task_queues: TaskQueueSet,

    /// Microtask queue
    microtasks: MicrotaskQueue,

    /// Cross-thread task queue (Phase 1.20)
    /// Tasks posted from any thread via postTaskFromAnyThread()
    cross_thread_queue: MpscQueue,

    /// Thread pool for blocking operations (Phase 1.19)
    pool: ?*ThreadPool = null,

    /// Running flag
    running: std.atomic.Value(bool),

    /// Statistics
    ticks: usize = 0,
    macrotasks_executed: usize = 0,
    microtask_checkpoints: usize = 0,
    cross_thread_tasks_processed: usize = 0,
    pool_completions_processed: usize = 0,

    const Self = @This();

    /// Initialize scheduler
    pub fn init() Self {
        return .{
            .task_queues = TaskQueueSet.init(),
            .microtasks = MicrotaskQueue.init(),
            .cross_thread_queue = MpscQueue.init(),
            .running = std.atomic.Value(bool).init(false),
        };
    }

    /// Initialize scheduler with thread pool
    pub fn initWithPool(allocator: std.mem.Allocator, thread_count: usize) !Self {
        var self = init();
        self.pool = try ThreadPool.init(allocator, thread_count);
        return self;
    }

    /// Deinitialize scheduler
    pub fn deinit(self: *Self) void {
        if (self.pool) |pool| {
            pool.deinit();
            self.pool = null;
        }
    }

    /// Enqueue a macrotask
    pub fn enqueueMacrotask(self: *Self, task: *TaskNode, priority: TaskPriority) void {
        self.task_queues.enqueue(task, priority);
    }

    /// Enqueue a microtask
    pub fn enqueueMicrotask(self: *Self, task: *MicrotaskNode) void {
        self.microtasks.enqueue(task);
    }

    /// Perform a microtask checkpoint
    ///
    /// Drains the entire microtask queue.
    /// Called after each macrotask execution.
    pub fn performMicrotaskCheckpoint(self: *Self) usize {
        self.microtask_checkpoints += 1;
        return self.microtasks.performCheckpoint();
    }

    /// Execute one tick of the event loop
    ///
    /// Returns true if work was performed (macrotask or microtask).
    pub fn tick(self: *Self) bool {
        self.ticks += 1;
        var did_work = false;

        // Step 0a: Process cross-thread tasks (Phase 1.20)
        const cross_thread_count = self.processCrossThreadTasks();
        if (cross_thread_count > 0) {
            did_work = true;
        }

        // Step 0b: Process thread pool completions (Phase 1.19)
        const completion_count = self.processPoolCompletions();
        if (completion_count > 0) {
            did_work = true;
        }

        // Step 1: Select and execute ONE macrotask (if any)
        if (self.task_queues.dequeue()) |task| {
            task.execute();
            self.macrotasks_executed += 1;
            did_work = true;
        }

        // Step 2: Perform microtask checkpoint
        const microtasks_run = self.performMicrotaskCheckpoint();
        if (microtasks_run > 0) {
            did_work = true;
        }

        // Step 3: Update rendering would go here (not implemented)

        return did_work;
    }

    /// Process tasks posted from other threads (Phase 1.20)
    ///
    /// Drains the cross-thread queue and enqueues tasks into the main task queues.
    fn processCrossThreadTasks(self: *Self) usize {
        var count: usize = 0;

        while (self.cross_thread_queue.pop()) |node| {
            const cross_task: *CrossThreadTask = @fieldParentPtr("mpsc_node", node);
            self.task_queues.enqueue(&cross_task.task, cross_task.priority);
            count += 1;
        }

        self.cross_thread_tasks_processed += count;
        return count;
    }

    /// Process thread pool completions (Phase 1.19)
    ///
    /// Polls the thread pool for completed work and invokes completion callbacks.
    fn processPoolCompletions(self: *Self) usize {
        const pool = self.pool orelse return 0;
        var count: usize = 0;

        while (pool.pollCompletion()) |work| {
            if (work.completion_fn) |cb| {
                cb(work.user_data, work.result);
            }
            count += 1;
        }

        self.pool_completions_processed += count;
        return count;
    }

    /// Post a task from any thread (Phase 1.20)
    ///
    /// Thread-safe: can be called from any thread.
    /// The task will be processed in the next event loop tick.
    pub fn postTaskFromAnyThread(self: *Self, task: *CrossThreadTask) void {
        self.cross_thread_queue.push(&task.mpsc_node);
    }

    /// Submit work to the thread pool (Phase 1.19)
    ///
    /// The work will be executed on a worker thread.
    /// If completion_fn is set, it will be called on the main thread
    /// after the work completes (via processPoolCompletions).
    pub fn submitWork(self: *Self, work: *WorkItem) bool {
        const pool = self.pool orelse return false;
        pool.submit(work);
        return true;
    }

    /// Get the thread pool (if available)
    pub fn getPool(self: *Self) ?*ThreadPool {
        return self.pool;
    }

    /// Run event loop until completion
    ///
    /// Runs until all queues are empty and stop is called.
    /// In practice, this would integrate with I/O polling.
    pub fn runUntilEmpty(self: *Self) void {
        self.running.store(true, .release);
        while (self.running.load(.acquire) and !self.isEmpty()) {
            _ = self.tick();
        }
        self.running.store(false, .release);
    }

    /// Run event loop for N ticks
    pub fn runForTicks(self: *Self, max_ticks: usize) usize {
        self.running.store(true, .release);
        var executed: usize = 0;
        while (self.running.load(.acquire) and executed < max_ticks) {
            if (!self.tick()) break;
            executed += 1;
        }
        self.running.store(false, .release);
        return executed;
    }

    /// Stop the event loop
    ///
    /// Thread-safe: can be called from any thread.
    pub fn stop(self: *Self) void {
        self.running.store(false, .release);
    }

    /// Check if all queues are empty
    pub fn isEmpty(self: *const Self) bool {
        return self.task_queues.isEmpty() and self.microtasks.isEmpty();
    }

    /// Check if running
    pub fn isRunning(self: *const Self) bool {
        return self.running.load(.acquire);
    }

    /// Get scheduler statistics
    pub const Stats = struct {
        ticks: usize,
        macrotasks_executed: usize,
        microtask_checkpoints: usize,
        pending_macrotasks: usize,
        pending_microtasks: usize,
        cross_thread_tasks_processed: usize,
        pool_completions_processed: usize,
    };

    pub fn getStats(self: *const Self) Stats {
        return .{
            .ticks = self.ticks,
            .macrotasks_executed = self.macrotasks_executed,
            .microtask_checkpoints = self.microtask_checkpoints,
            .pending_macrotasks = self.task_queues.pendingCount(),
            .pending_microtasks = self.microtasks.len(),
            .cross_thread_tasks_processed = self.cross_thread_tasks_processed,
            .pool_completions_processed = self.pool_completions_processed,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Scheduler - basic macrotask execution" {
    var scheduler = Scheduler.init();

    var executed = false;
    var task = TaskNode.init(setFlagCallback, &executed, .timer);

    scheduler.enqueueMacrotask(&task, .timer);
    try std.testing.expect(!executed);

    const did_work = scheduler.tick();
    try std.testing.expect(did_work);
    try std.testing.expect(executed);
    try std.testing.expect(scheduler.isEmpty());
}

test "Scheduler - macrotask then microtask ordering" {
    var scheduler = Scheduler.init();

    var order: [10]usize = [_]usize{0} ** 10;
    var order_idx: usize = 0;

    var ctx = OrderContext{
        .order = &order,
        .order_idx = &order_idx,
        .id = 1,
    };

    var macro_task = TaskNode.init(orderCallback, &ctx, .timer);
    scheduler.enqueueMacrotask(&macro_task, .timer);

    var micro_ctx = OrderContext{
        .order = &order,
        .order_idx = &order_idx,
        .id = 2,
    };
    var micro_task = MicrotaskNode.init(microOrderCallback, &micro_ctx);
    scheduler.enqueueMicrotask(&micro_task);

    // Single tick should execute macrotask, then microtask checkpoint
    _ = scheduler.tick();

    try std.testing.expectEqual(@as(usize, 1), order[0]); // macrotask first
    try std.testing.expectEqual(@as(usize, 2), order[1]); // microtask after
}

test "Scheduler - runUntilEmpty" {
    var scheduler = Scheduler.init();

    var counter: usize = 0;
    var task1 = TaskNode.init(countCallback, &counter, .timer);
    var task2 = TaskNode.init(countCallback, &counter, .timer);
    var task3 = TaskNode.init(countCallback, &counter, .networking);

    scheduler.enqueueMacrotask(&task1, .timer);
    scheduler.enqueueMacrotask(&task2, .timer);
    scheduler.enqueueMacrotask(&task3, .networking);

    scheduler.runUntilEmpty();

    try std.testing.expectEqual(@as(usize, 3), counter);
    try std.testing.expect(scheduler.isEmpty());
}

test "Scheduler - statistics" {
    var scheduler = Scheduler.init();

    var counter: usize = 0;
    var task1 = TaskNode.init(countCallback, &counter, .timer);
    var micro1 = MicrotaskNode.init(microCountCallback, &counter);

    scheduler.enqueueMacrotask(&task1, .timer);
    scheduler.enqueueMicrotask(&micro1);

    _ = scheduler.tick();

    const stats = scheduler.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.ticks);
    try std.testing.expectEqual(@as(usize, 1), stats.macrotasks_executed);
    try std.testing.expectEqual(@as(usize, 1), stats.microtask_checkpoints);
    try std.testing.expectEqual(@as(usize, 0), stats.pending_macrotasks);
    try std.testing.expectEqual(@as(usize, 0), stats.pending_microtasks);
}

test "Scheduler - priority ordering" {
    var scheduler = Scheduler.init();

    var order: [10]usize = [_]usize{0} ** 10;
    var order_idx: usize = 0;

    // Enqueue in reverse priority order
    var idle_ctx = OrderContext{ .order = &order, .order_idx = &order_idx, .id = 5 };
    var idle_task = TaskNode.init(orderCallback, &idle_ctx, .idle);
    scheduler.enqueueMacrotask(&idle_task, .idle);

    var timer_ctx = OrderContext{ .order = &order, .order_idx = &order_idx, .id = 4 };
    var timer_task = TaskNode.init(orderCallback, &timer_ctx, .timer);
    scheduler.enqueueMacrotask(&timer_task, .timer);

    var user_ctx = OrderContext{ .order = &order, .order_idx = &order_idx, .id = 1 };
    var user_task = TaskNode.init(orderCallback, &user_ctx, .user_interaction);
    scheduler.enqueueMacrotask(&user_task, .user_interaction);

    // Run all tasks
    scheduler.runUntilEmpty();

    // Should execute in priority order
    try std.testing.expectEqual(@as(usize, 1), order[0]); // user_interaction
    try std.testing.expectEqual(@as(usize, 4), order[1]); // timer
    try std.testing.expectEqual(@as(usize, 5), order[2]); // idle
}

// Test helpers

fn setFlagCallback(user_data: ?*anyopaque) void {
    const flag: *bool = @ptrCast(@alignCast(user_data.?));
    flag.* = true;
}

fn countCallback(user_data: ?*anyopaque) void {
    const counter: *usize = @ptrCast(@alignCast(user_data.?));
    counter.* += 1;
}

fn microCountCallback(user_data: ?*anyopaque) void {
    const counter: *usize = @ptrCast(@alignCast(user_data.?));
    counter.* += 1;
}

const OrderContext = struct {
    order: *[10]usize,
    order_idx: *usize,
    id: usize,
};

fn orderCallback(user_data: ?*anyopaque) void {
    const ctx: *OrderContext = @ptrCast(@alignCast(user_data.?));
    ctx.order[ctx.order_idx.*] = ctx.id;
    ctx.order_idx.* += 1;
}

fn microOrderCallback(user_data: ?*anyopaque) void {
    const ctx: *OrderContext = @ptrCast(@alignCast(user_data.?));
    ctx.order[ctx.order_idx.*] = ctx.id;
    ctx.order_idx.* += 1;
}

// ============================================================================
// Phase 1.19/1.20 Tests
// ============================================================================

test "Scheduler - cross-thread task posting" {
    var scheduler = Scheduler.init();

    var counter: usize = 0;

    // Create cross-thread tasks
    var task1 = CrossThreadTask.init(countCallback, &counter, .timer);
    var task2 = CrossThreadTask.init(countCallback, &counter, .networking);

    // Post from "another thread" (same thread in test, but uses MPSC queue)
    scheduler.postTaskFromAnyThread(&task1);
    scheduler.postTaskFromAnyThread(&task2);

    // Tick once to process cross-thread tasks into main queue
    _ = scheduler.tick();

    // Check tasks were processed and enqueued
    try std.testing.expectEqual(@as(usize, 2), scheduler.getStats().cross_thread_tasks_processed);

    // Run remaining tasks
    scheduler.runUntilEmpty();

    try std.testing.expectEqual(@as(usize, 2), counter);
}

test "Scheduler - thread pool completion flow" {
    var scheduler = try Scheduler.initWithPool(std.testing.allocator, 2);
    defer scheduler.deinit();

    var completed = std.atomic.Value(bool).init(false);
    var work = WorkItem.initWithCompletion(
        noopWorkCallback,
        completionFlagCallback,
        &completed,
    );

    // Submit work to pool
    try std.testing.expect(scheduler.submitWork(&work));

    // Wait for completion to be processed
    var attempts: usize = 0;
    while (attempts < 1000) : (attempts += 1) {
        _ = scheduler.tick();
        if (completed.load(.acquire)) break;
        std.Thread.yield() catch {};
    }

    try std.testing.expect(completed.load(.acquire));
    try std.testing.expect(scheduler.getStats().pool_completions_processed >= 1);
}

test "Scheduler - stop from any thread" {
    var scheduler = Scheduler.init();

    // Start running
    scheduler.running.store(true, .release);
    try std.testing.expect(scheduler.isRunning());

    // Stop (simulating call from another thread)
    scheduler.stop();
    try std.testing.expect(!scheduler.isRunning());
}

fn atomicCountCallback(user_data: ?*anyopaque) void {
    const counter: *std.atomic.Value(usize) = @ptrCast(@alignCast(user_data.?));
    _ = counter.fetchAdd(1, .acq_rel);
}

fn noopWorkCallback(_: ?*anyopaque) void {}

fn completionFlagCallback(user_data: ?*anyopaque, _: ?*anyopaque) void {
    const flag: *std.atomic.Value(bool) = @ptrCast(@alignCast(user_data.?));
    flag.store(true, .release);
}
