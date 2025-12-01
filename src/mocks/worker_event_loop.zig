//! Mock Worker Event Loop for Service Workers
//!
//! TODO(html-spec): Replace this mock with real HTML event loop
//! when the HTML specification event loop section is implemented.
//! See: https://html.spec.whatwg.org/multipage/webappapis.html#event-loops
//!
//! The event loop is central to JavaScript execution. This mock provides
//! a simplified task queue for testing Service Worker behavior.
//!
//! HTML spec concepts mocked:
//! - Task queues (multiple named queues)
//! - Microtask queue
//! - Task scheduling
//! - Event loop processing model

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Task function type.
pub const TaskFn = *const fn (ctx: ?*anyopaque) void;

/// A queued task.
pub const Task = struct {
    /// The task callback.
    callback: TaskFn,

    /// Task context/data.
    context: ?*anyopaque,

    /// Task source (for debugging/filtering).
    source: TaskSource,

    /// Whether this task has been cancelled.
    cancelled: bool = false,

    /// Unique task ID.
    id: u64,
};

/// Task source categories per HTML spec.
pub const TaskSource = enum {
    /// DOM manipulation task source.
    dom_manipulation,

    /// User interaction task source.
    user_interaction,

    /// Networking task source.
    networking,

    /// History traversal task source.
    history_traversal,

    /// Timer task source (setTimeout, setInterval).
    timer,

    /// Service worker task source.
    service_worker,

    /// Generic/other task source.
    generic,
};

/// Mock Worker Event Loop.
///
/// Provides a simplified event loop with:
/// - Multiple task queues (by source)
/// - Microtask queue
/// - Synchronous task execution for testing
///
/// In real implementation:
/// - Would integrate with JS engine
/// - Would handle async I/O
/// - Would support rendering (for Window)
/// - Would handle worker lifecycle
pub const WorkerEventLoop = struct {
    allocator: Allocator,

    /// Task queues by source.
    task_queues: std.EnumArray(TaskSource, std.ArrayListUnmanaged(Task)),

    /// Microtask queue.
    microtask_queue: std.ArrayListUnmanaged(Task),

    /// Whether the event loop is running.
    running: bool = false,

    /// Whether the event loop should terminate.
    should_terminate: bool = false,

    /// Counter for generating unique task IDs.
    next_task_id: u64 = 0,

    /// Currently executing task (if any).
    current_task: ?*Task = null,

    /// Callback when loop becomes idle.
    on_idle: ?*const fn (*WorkerEventLoop) void = null,

    const Self = @This();

    /// Initialize the event loop.
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Initialize task queues for each source
        var task_queues = std.EnumArray(TaskSource, std.ArrayListUnmanaged(Task)).initUndefined();
        inline for (std.meta.fields(TaskSource)) |field| {
            const source: TaskSource = @enumFromInt(field.value);
            task_queues.set(source, .{});
        }

        self.* = .{
            .allocator = allocator,
            .task_queues = task_queues,
            .microtask_queue = .{},
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Clear all task queues
        inline for (std.meta.fields(TaskSource)) |field| {
            const source: TaskSource = @enumFromInt(field.value);
            self.task_queues.getPtr(source).deinit(self.allocator);
        }
        self.microtask_queue.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Queue a task.
    ///
    /// Per HTML spec "queue a task":
    /// 1. Let task be a new task
    /// 2. Set task's steps to steps
    /// 3. Set task's source to source
    /// 4. Set task's document to document (N/A for workers)
    /// 5. Set task's script evaluation environment settings object
    /// 6. Append task to event loop's task queue
    pub fn queueTask(self: *Self, source: TaskSource, callback: TaskFn, context: ?*anyopaque) u64 {
        const task = Task{
            .callback = callback,
            .context = context,
            .source = source,
            .id = self.next_task_id,
        };
        self.next_task_id += 1;

        self.task_queues.getPtr(source).append(self.allocator, task) catch {
            // In mock, silently fail if OOM
            return task.id;
        };

        return task.id;
    }

    /// Queue a microtask.
    ///
    /// Per HTML spec "queue a microtask":
    /// - Microtasks run after each task
    /// - Microtasks can queue more microtasks
    /// - Microtask queue is drained completely
    pub fn queueMicrotask(self: *Self, callback: TaskFn, context: ?*anyopaque) u64 {
        const task = Task{
            .callback = callback,
            .context = context,
            .source = .generic,
            .id = self.next_task_id,
        };
        self.next_task_id += 1;

        self.microtask_queue.append(self.allocator, task) catch {
            return task.id;
        };

        return task.id;
    }

    /// Cancel a task by ID.
    ///
    /// Returns true if task was found and cancelled.
    pub fn cancelTask(self: *Self, task_id: u64) bool {
        // Search all queues
        inline for (std.meta.fields(TaskSource)) |field| {
            const source: TaskSource = @enumFromInt(field.value);
            const queue = self.task_queues.getPtr(source);
            for (queue.items) |*task| {
                if (task.id == task_id) {
                    task.cancelled = true;
                    return true;
                }
            }
        }
        return false;
    }

    /// Perform a microtask checkpoint.
    ///
    /// Per HTML spec:
    /// - If performing microtask checkpoint flag is set, return
    /// - Set performing microtask checkpoint flag
    /// - While microtask queue is not empty:
    ///   - Dequeue oldest microtask
    ///   - Run microtask
    /// - Unset performing microtask checkpoint flag
    pub fn performMicrotaskCheckpoint(self: *Self) void {
        while (self.microtask_queue.items.len > 0) {
            const task = self.microtask_queue.orderedRemove(0);
            if (!task.cancelled) {
                task.callback(task.context);
            }
        }
    }

    /// Run one task from any queue.
    ///
    /// Returns true if a task was run, false if no tasks available.
    pub fn runOneTask(self: *Self) bool {
        // Per HTML spec, select oldest task from any task queue
        // For simplicity, we check queues in order of TaskSource enum
        inline for (std.meta.fields(TaskSource)) |field| {
            const source: TaskSource = @enumFromInt(field.value);
            const queue = self.task_queues.getPtr(source);
            if (queue.items.len > 0) {
                const task = queue.orderedRemove(0);
                if (!task.cancelled) {
                    task.callback(task.context);
                    // Run microtask checkpoint after each task
                    self.performMicrotaskCheckpoint();
                }
                return true;
            }
        }
        return false;
    }

    /// Run all pending tasks until queues are empty.
    ///
    /// This is for testing - runs synchronously.
    pub fn runAllTasks(self: *Self) void {
        while (self.runOneTask()) {}
    }

    /// Run tasks from a specific source.
    pub fn runTasksFromSource(self: *Self, source: TaskSource) void {
        const queue = self.task_queues.getPtr(source);
        while (queue.items.len > 0) {
            const task = queue.orderedRemove(0);
            if (!task.cancelled) {
                task.callback(task.context);
                self.performMicrotaskCheckpoint();
            }
        }
    }

    /// Check if there are any pending tasks.
    pub fn hasPendingTasks(self: *const Self) bool {
        inline for (std.meta.fields(TaskSource)) |field| {
            const source: TaskSource = @enumFromInt(field.value);
            if (self.task_queues.get(source).items.len > 0) {
                return true;
            }
        }
        return false;
    }

    /// Check if there are any pending microtasks.
    pub fn hasPendingMicrotasks(self: *const Self) bool {
        return self.microtask_queue.items.len > 0;
    }

    /// Get total number of pending tasks across all queues.
    pub fn getPendingTaskCount(self: *const Self) usize {
        var count: usize = 0;
        inline for (std.meta.fields(TaskSource)) |field| {
            const source: TaskSource = @enumFromInt(field.value);
            count += self.task_queues.get(source).items.len;
        }
        return count;
    }

    /// Signal that the event loop should terminate.
    pub fn terminate(self: *Self) void {
        self.should_terminate = true;
    }

    /// Check if the event loop should terminate.
    pub fn shouldTerminate(self: *const Self) bool {
        return self.should_terminate;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "WorkerEventLoop.init and deinit" {
    const allocator = std.testing.allocator;

    const loop = try WorkerEventLoop.init(allocator);
    defer loop.deinit();

    try std.testing.expect(!loop.hasPendingTasks());
    try std.testing.expect(!loop.hasPendingMicrotasks());
}

test "WorkerEventLoop.queueTask adds task" {
    const allocator = std.testing.allocator;

    const loop = try WorkerEventLoop.init(allocator);
    defer loop.deinit();

    _ = loop.queueTask(.generic, struct {
        fn callback(_: ?*anyopaque) void {}
    }.callback, null);

    try std.testing.expect(loop.hasPendingTasks());
    try std.testing.expectEqual(@as(usize, 1), loop.getPendingTaskCount());
}

test "WorkerEventLoop.runOneTask executes and removes task" {
    const allocator = std.testing.allocator;

    const loop = try WorkerEventLoop.init(allocator);
    defer loop.deinit();

    var executed = false;
    _ = loop.queueTask(.generic, struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(ctx.?));
            ptr.* = true;
        }
    }.callback, @ptrCast(&executed));

    const ran = loop.runOneTask();
    try std.testing.expect(ran);
    try std.testing.expect(executed);
    try std.testing.expect(!loop.hasPendingTasks());
}

test "WorkerEventLoop.queueMicrotask" {
    const allocator = std.testing.allocator;

    const loop = try WorkerEventLoop.init(allocator);
    defer loop.deinit();

    var executed = false;
    _ = loop.queueMicrotask(struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(ctx.?));
            ptr.* = true;
        }
    }.callback, @ptrCast(&executed));

    try std.testing.expect(loop.hasPendingMicrotasks());

    loop.performMicrotaskCheckpoint();
    try std.testing.expect(executed);
    try std.testing.expect(!loop.hasPendingMicrotasks());
}

test "WorkerEventLoop.runOneTask triggers microtask checkpoint" {
    const allocator = std.testing.allocator;

    const loop = try WorkerEventLoop.init(allocator);
    defer loop.deinit();

    // Simple test: queue a task, queue a microtask separately
    // Verify microtasks are run after task via checkpoint
    var task_ran = false;
    var microtask_ran = false;

    // Queue the task
    _ = loop.queueTask(.generic, struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(ctx.?));
            ptr.* = true;
        }
    }.callback, @ptrCast(&task_ran));

    // Queue a microtask
    _ = loop.queueMicrotask(struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(ctx.?));
            ptr.* = true;
        }
    }.callback, @ptrCast(&microtask_ran));

    // Run one task - should trigger microtask checkpoint
    _ = loop.runOneTask();

    // Both should have run
    try std.testing.expect(task_ran);
    try std.testing.expect(microtask_ran);
}

test "WorkerEventLoop.cancelTask" {
    const allocator = std.testing.allocator;

    const loop = try WorkerEventLoop.init(allocator);
    defer loop.deinit();

    var executed = false;
    const task_id = loop.queueTask(.generic, struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *bool = @ptrCast(@alignCast(ctx.?));
            ptr.* = true;
        }
    }.callback, @ptrCast(&executed));

    const cancelled = loop.cancelTask(task_id);
    try std.testing.expect(cancelled);

    // Task is still in queue but marked cancelled
    _ = loop.runOneTask();
    try std.testing.expect(!executed);
}

test "WorkerEventLoop.runAllTasks" {
    const allocator = std.testing.allocator;

    const loop = try WorkerEventLoop.init(allocator);
    defer loop.deinit();

    var count: u32 = 0;
    _ = loop.queueTask(.generic, struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *u32 = @ptrCast(@alignCast(ctx.?));
            ptr.* += 1;
        }
    }.callback, @ptrCast(&count));
    _ = loop.queueTask(.timer, struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *u32 = @ptrCast(@alignCast(ctx.?));
            ptr.* += 1;
        }
    }.callback, @ptrCast(&count));
    _ = loop.queueTask(.networking, struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *u32 = @ptrCast(@alignCast(ctx.?));
            ptr.* += 1;
        }
    }.callback, @ptrCast(&count));

    try std.testing.expectEqual(@as(usize, 3), loop.getPendingTaskCount());

    loop.runAllTasks();
    try std.testing.expectEqual(@as(u32, 3), count);
    try std.testing.expect(!loop.hasPendingTasks());
}

test "WorkerEventLoop.terminate" {
    const allocator = std.testing.allocator;

    const loop = try WorkerEventLoop.init(allocator);
    defer loop.deinit();

    try std.testing.expect(!loop.shouldTerminate());

    loop.terminate();
    try std.testing.expect(loop.shouldTerminate());
}
