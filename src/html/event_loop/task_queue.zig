//! HTML Event Loop Task Queue
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#task-queue
//! HTML Standard §8.1.7 "Event loops" - Task queues
//!
//! An event loop has one or more task queues. A task queue is a set of tasks.
//! Task queues are sets, not queues, because the event loop processing model
//! grabs the first *runnable* task from the chosen queue, instead of dequeuing
//! the first task.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const task_mod = @import("task.zig");
const Task = task_mod.Task;
const TaskSource = task_mod.TaskSource;

/// A task queue containing tasks from one or more task sources.
///
/// HTML Standard §8.1.7 lines 2847-2849:
/// "Task queues are sets, not queues, because the event loop processing model
/// grabs the first *runnable* task from the chosen queue, instead of dequeuing
/// the first task."
pub const TaskQueue = struct {
    /// The tasks in this queue, ordered by insertion time.
    tasks: infra.List(*Task),

    /// The task sources associated with this queue.
    sources: infra.List(TaskSource),

    /// Allocator for memory management.
    allocator: Allocator,

    /// Initialize a new task queue.
    pub fn init(allocator: Allocator) TaskQueue {
        return TaskQueue{
            .tasks = infra.List(*Task).init(allocator),
            .sources = infra.List(TaskSource).init(allocator),
            .allocator = allocator,
        };
    }

    /// Free all resources associated with this task queue.
    pub fn deinit(self: *TaskQueue) void {
        // Free all tasks
        const slice = self.tasks.toSlice();
        for (slice) |t| {
            t.deinit();
            self.allocator.destroy(t);
        }
        self.tasks.deinit();
        self.sources.deinit();
    }

    /// Associate a task source with this queue.
    pub fn addSource(self: *TaskQueue, source: TaskSource) !void {
        if (!self.sources.contains(source)) {
            try self.sources.append(source);
        }
    }

    /// Check if this queue handles tasks from the given source.
    pub fn hasSource(self: *const TaskQueue, source: TaskSource) bool {
        return self.sources.contains(source);
    }

    /// Enqueue a task to this queue.
    /// HTML Standard §8.1.7.1 "Queuing tasks" line 2928:
    /// "Append task to queue."
    pub fn enqueue(self: *TaskQueue, t: *Task) !void {
        try self.tasks.append(t);
    }

    /// Get the first runnable task from the queue without removing it.
    pub fn peekRunnable(self: *const TaskQueue) ?*Task {
        const slice = self.tasks.toSlice();
        for (slice) |t| {
            if (t.isRunnable()) {
                return t;
            }
        }
        return null;
    }

    /// Remove and return the first runnable task from the queue.
    ///
    /// HTML Standard §8.1.7.2 "Processing model" line 2998-2999:
    /// "Set oldestTask to the first runnable task in taskQueue,
    /// and remove it from taskQueue."
    pub fn dequeueRunnable(self: *TaskQueue) ?*Task {
        const slice = self.tasks.toSlice();
        for (slice, 0..) |t, i| {
            if (t.isRunnable()) {
                _ = self.tasks.remove(i) catch unreachable;
                return t;
            }
        }
        return null;
    }

    /// Check if the queue has at least one runnable task.
    ///
    /// HTML Standard §8.1.7.2 "Processing model" line 2990:
    /// "If the event loop has a task queue with at least one runnable task"
    pub fn hasRunnableTask(self: *const TaskQueue) bool {
        return self.peekRunnable() != null;
    }

    /// Check if the queue is empty.
    pub fn isEmpty(self: *const TaskQueue) bool {
        return self.tasks.isEmpty();
    }

    /// Get the number of tasks in the queue.
    pub fn size(self: *const TaskQueue) usize {
        return self.tasks.len;
    }

    /// Remove a specific task from the queue (by task ID).
    pub fn removeTask(self: *TaskQueue, task_id: u64) ?*Task {
        const slice = self.tasks.toSlice();
        for (slice, 0..) |t, i| {
            if (t.id == task_id) {
                _ = self.tasks.remove(i) catch unreachable;
                return t;
            }
        }
        return null;
    }

    /// Clear all tasks from the queue.
    pub fn clear(self: *TaskQueue) void {
        const slice = self.tasks.toSlice();
        for (slice) |t| {
            t.deinit();
            self.allocator.destroy(t);
        }
        self.tasks.clear();
    }
};

/// A collection of task queues for an event loop.
///
/// The event loop processing model chooses which task queue to process next
/// in an implementation-defined manner. This allows implementations to
/// prioritize certain types of tasks (e.g., user interaction) over others.
pub const TaskQueueSet = struct {
    /// All task queues in this set.
    queues: infra.List(*TaskQueue),

    /// Mapping from task source to queue index for fast lookup.
    source_to_queue: std.AutoHashMap(TaskSource, usize),

    /// Allocator for memory management.
    allocator: Allocator,

    /// Initialize a new task queue set with default queues.
    pub fn init(allocator: Allocator) !TaskQueueSet {
        var self = TaskQueueSet{
            .queues = infra.List(*TaskQueue).init(allocator),
            .source_to_queue = std.AutoHashMap(TaskSource, usize).init(allocator),
            .allocator = allocator,
        };

        // Create default task queues for different priorities
        // High priority: user interaction
        const user_queue = try allocator.create(TaskQueue);
        user_queue.* = TaskQueue.init(allocator);
        try user_queue.addSource(.user_interaction);
        try self.queues.append(user_queue);
        try self.source_to_queue.put(.user_interaction, 0);

        // Normal priority: most other sources
        const normal_queue = try allocator.create(TaskQueue);
        normal_queue.* = TaskQueue.init(allocator);
        try normal_queue.addSource(.dom_manipulation);
        try normal_queue.addSource(.networking);
        try normal_queue.addSource(.navigation_and_traversal);
        try normal_queue.addSource(.timer);
        try normal_queue.addSource(.history_traversal);
        try normal_queue.addSource(.media_element);
        try normal_queue.addSource(.storage);
        try normal_queue.addSource(.message_port);
        try normal_queue.addSource(.websocket);
        try normal_queue.addSource(.indexeddb);
        try self.queues.append(normal_queue);
        try self.source_to_queue.put(.dom_manipulation, 1);
        try self.source_to_queue.put(.networking, 1);
        try self.source_to_queue.put(.navigation_and_traversal, 1);
        try self.source_to_queue.put(.timer, 1);
        try self.source_to_queue.put(.history_traversal, 1);
        try self.source_to_queue.put(.media_element, 1);
        try self.source_to_queue.put(.storage, 1);
        try self.source_to_queue.put(.message_port, 1);
        try self.source_to_queue.put(.websocket, 1);
        try self.source_to_queue.put(.indexeddb, 1);

        // Rendering priority
        const render_queue = try allocator.create(TaskQueue);
        render_queue.* = TaskQueue.init(allocator);
        try render_queue.addSource(.rendering);
        try render_queue.addSource(.canvas_blob_serialization);
        try self.queues.append(render_queue);
        try self.source_to_queue.put(.rendering, 2);
        try self.source_to_queue.put(.canvas_blob_serialization, 2);

        // Low priority: idle callbacks, performance
        const low_queue = try allocator.create(TaskQueue);
        low_queue.* = TaskQueue.init(allocator);
        try low_queue.addSource(.idle_callback);
        try low_queue.addSource(.performance_timeline);
        try self.queues.append(low_queue);
        try self.source_to_queue.put(.idle_callback, 3);
        try self.source_to_queue.put(.performance_timeline, 3);

        // Microtask source (for when microtasks are moved to regular queues)
        const microtask_queue = try allocator.create(TaskQueue);
        microtask_queue.* = TaskQueue.init(allocator);
        try microtask_queue.addSource(.microtask);
        try self.queues.append(microtask_queue);
        try self.source_to_queue.put(.microtask, 4);

        return self;
    }

    /// Free all resources.
    pub fn deinit(self: *TaskQueueSet) void {
        const slice = self.queues.toSlice();
        for (slice) |q| {
            q.deinit();
            self.allocator.destroy(q);
        }
        self.queues.deinit();
        self.source_to_queue.deinit();
    }

    /// Get the task queue for a given task source.
    pub fn getQueueForSource(self: *TaskQueueSet, source: TaskSource) ?*TaskQueue {
        const idx = self.source_to_queue.get(source) orelse return null;
        return self.queues.get(idx);
    }

    /// Queue a task to the appropriate queue based on its source.
    pub fn queueTask(self: *TaskQueueSet, t: *Task) !void {
        const queue = self.getQueueForSource(t.source) orelse return error.NoQueueForSource;
        try queue.enqueue(t);
    }

    /// Check if any queue has a runnable task.
    pub fn hasRunnableTask(self: *const TaskQueueSet) bool {
        const slice = self.queues.toSlice();
        for (slice) |q| {
            if (q.hasRunnableTask()) return true;
        }
        return false;
    }

    /// Select a task queue that has a runnable task.
    /// This is implementation-defined; we use a simple priority order.
    ///
    /// HTML Standard §8.1.7.2 line 2992:
    /// "Let taskQueue be one such task queue, chosen in an implementation-defined manner."
    pub fn selectRunnableQueue(self: *TaskQueueSet) ?*TaskQueue {
        // Priority order: user interaction > normal > rendering > low > microtask
        const slice = self.queues.toSlice();
        for (slice) |q| {
            if (q.hasRunnableTask()) return q;
        }
        return null;
    }

    /// Dequeue and return the oldest runnable task from any queue.
    /// Uses priority ordering to select the queue.
    pub fn dequeueRunnable(self: *TaskQueueSet) ?*Task {
        const queue = self.selectRunnableQueue() orelse return null;
        return queue.dequeueRunnable();
    }
};

test "TaskQueue - basic operations" {
    const allocator = std.testing.allocator;

    var queue = TaskQueue.init(allocator);
    defer queue.deinit();

    // Add source
    try queue.addSource(.timer);
    try std.testing.expect(queue.hasSource(.timer));
    try std.testing.expect(!queue.hasSource(.networking));

    // Create and enqueue a task
    const t = try allocator.create(Task);
    t.* = Task.init(
        allocator,
        1,
        .timer,
        struct {
            fn steps(_: ?*anyopaque) void {}
        }.steps,
        null,
        null,
    );
    try queue.enqueue(t);

    try std.testing.expectEqual(@as(usize, 1), queue.size());
    try std.testing.expect(queue.hasRunnableTask());

    // Dequeue the task
    const dequeued = queue.dequeueRunnable();
    try std.testing.expect(dequeued != null);
    try std.testing.expectEqual(@as(u64, 1), dequeued.?.id);
    try std.testing.expectEqual(@as(usize, 0), queue.size());

    // Clean up the dequeued task
    dequeued.?.deinit();
    allocator.destroy(dequeued.?);
}

test "TaskQueue - runnable filtering" {
    const allocator = std.testing.allocator;

    var queue = TaskQueue.init(allocator);
    defer queue.deinit();

    try queue.addSource(.timer);

    // Create task 1 (runnable)
    const t1 = try allocator.create(Task);
    t1.* = Task.init(
        allocator,
        1,
        .timer,
        struct {
            fn steps(_: ?*anyopaque) void {}
        }.steps,
        null,
        null,
    );
    try queue.enqueue(t1);

    // Create task 2 (cancelled)
    const t2 = try allocator.create(Task);
    t2.* = Task.init(
        allocator,
        2,
        .timer,
        struct {
            fn steps(_: ?*anyopaque) void {}
        }.steps,
        null,
        null,
    );
    t2.cancel();
    try queue.enqueue(t2);

    // Create task 3 (runnable)
    const t3 = try allocator.create(Task);
    t3.* = Task.init(
        allocator,
        3,
        .timer,
        struct {
            fn steps(_: ?*anyopaque) void {}
        }.steps,
        null,
        null,
    );
    try queue.enqueue(t3);

    // First runnable should be task 1
    const first = queue.dequeueRunnable();
    try std.testing.expect(first != null);
    try std.testing.expectEqual(@as(u64, 1), first.?.id);

    // Next runnable should be task 3 (task 2 is cancelled)
    const second = queue.dequeueRunnable();
    try std.testing.expect(second != null);
    try std.testing.expectEqual(@as(u64, 3), second.?.id);

    // Clean up dequeued tasks
    first.?.deinit();
    allocator.destroy(first.?);
    second.?.deinit();
    allocator.destroy(second.?);
}

test "TaskQueueSet - initialization" {
    const allocator = std.testing.allocator;

    var queue_set = try TaskQueueSet.init(allocator);
    defer queue_set.deinit();

    // Check that queues were created for all sources
    try std.testing.expect(queue_set.getQueueForSource(.user_interaction) != null);
    try std.testing.expect(queue_set.getQueueForSource(.timer) != null);
    try std.testing.expect(queue_set.getQueueForSource(.rendering) != null);
    try std.testing.expect(queue_set.getQueueForSource(.idle_callback) != null);
}

test "TaskQueueSet - queue task" {
    const allocator = std.testing.allocator;

    var queue_set = try TaskQueueSet.init(allocator);
    defer queue_set.deinit();

    // Create a task
    const t = try allocator.create(Task);
    t.* = Task.init(
        allocator,
        1,
        .timer,
        struct {
            fn steps(_: ?*anyopaque) void {}
        }.steps,
        null,
        null,
    );

    // Queue it
    try queue_set.queueTask(t);
    try std.testing.expect(queue_set.hasRunnableTask());

    // Dequeue it
    const dequeued = queue_set.dequeueRunnable();
    try std.testing.expect(dequeued != null);
    try std.testing.expectEqual(@as(u64, 1), dequeued.?.id);

    // Clean up
    dequeued.?.deinit();
    allocator.destroy(dequeued.?);
}

test "TaskQueueSet - priority ordering" {
    const allocator = std.testing.allocator;

    var queue_set = try TaskQueueSet.init(allocator);
    defer queue_set.deinit();

    // Create a low-priority task first
    const t1 = try allocator.create(Task);
    t1.* = Task.init(
        allocator,
        1,
        .idle_callback,
        struct {
            fn steps(_: ?*anyopaque) void {}
        }.steps,
        null,
        null,
    );
    try queue_set.queueTask(t1);

    // Create a high-priority task second
    const t2 = try allocator.create(Task);
    t2.* = Task.init(
        allocator,
        2,
        .user_interaction,
        struct {
            fn steps(_: ?*anyopaque) void {}
        }.steps,
        null,
        null,
    );
    try queue_set.queueTask(t2);

    // High priority should dequeue first even though queued second
    const first = queue_set.dequeueRunnable();
    try std.testing.expect(first != null);
    try std.testing.expectEqual(@as(u64, 2), first.?.id);

    const second = queue_set.dequeueRunnable();
    try std.testing.expect(second != null);
    try std.testing.expectEqual(@as(u64, 1), second.?.id);

    // Clean up
    first.?.deinit();
    allocator.destroy(first.?);
    second.?.deinit();
    allocator.destroy(second.?);
}
