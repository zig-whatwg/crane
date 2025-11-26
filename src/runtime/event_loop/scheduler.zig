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
//! ## References
//!
//! - WHATWG HTML Standard: Event loop processing model
//! - https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model

const std = @import("std");
const task_queue = @import("task_queue.zig");
const microtask = @import("microtask.zig");

pub const TaskQueueSet = task_queue.TaskQueueSet;
pub const TaskNode = task_queue.TaskNode;
pub const TaskPriority = task_queue.TaskPriority;
pub const TaskCallback = task_queue.TaskCallback;

pub const MicrotaskQueue = microtask.MicrotaskQueue;
pub const MicrotaskNode = microtask.MicrotaskNode;
pub const MicrotaskCallback = microtask.MicrotaskCallback;

/// Event loop scheduler state
pub const Scheduler = struct {
    /// Task queue set (macrotasks)
    task_queues: TaskQueueSet,

    /// Microtask queue
    microtasks: MicrotaskQueue,

    /// Running flag
    running: bool = false,

    /// Statistics
    ticks: usize = 0,
    macrotasks_executed: usize = 0,
    microtask_checkpoints: usize = 0,

    const Self = @This();

    /// Initialize scheduler
    pub fn init() Self {
        return .{
            .task_queues = TaskQueueSet.init(),
            .microtasks = MicrotaskQueue.init(),
        };
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

    /// Run event loop until completion
    ///
    /// Runs until all queues are empty and stop is called.
    /// In practice, this would integrate with I/O polling.
    pub fn runUntilEmpty(self: *Self) void {
        self.running = true;
        while (self.running and !self.isEmpty()) {
            _ = self.tick();
        }
        self.running = false;
    }

    /// Run event loop for N ticks
    pub fn runForTicks(self: *Self, max_ticks: usize) usize {
        self.running = true;
        var executed: usize = 0;
        while (self.running and executed < max_ticks) {
            if (!self.tick()) break;
            executed += 1;
        }
        self.running = false;
        return executed;
    }

    /// Stop the event loop
    pub fn stop(self: *Self) void {
        self.running = false;
    }

    /// Check if all queues are empty
    pub fn isEmpty(self: *const Self) bool {
        return self.task_queues.isEmpty() and self.microtasks.isEmpty();
    }

    /// Check if running
    pub fn isRunning(self: *const Self) bool {
        return self.running;
    }

    /// Get scheduler statistics
    pub const Stats = struct {
        ticks: usize,
        macrotasks_executed: usize,
        microtask_checkpoints: usize,
        pending_macrotasks: usize,
        pending_microtasks: usize,
    };

    pub fn getStats(self: *const Self) Stats {
        return .{
            .ticks = self.ticks,
            .macrotasks_executed = self.macrotasks_executed,
            .microtask_checkpoints = self.microtask_checkpoints,
            .pending_macrotasks = self.task_queues.pendingCount(),
            .pending_microtasks = self.microtasks.len(),
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
