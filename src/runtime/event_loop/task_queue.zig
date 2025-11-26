//! Priority-Based Task Queues for WHATWG Event Loop
//!
//! Implements the task queue set as defined in the WHATWG HTML Standard.
//! Each task source posts to its own queue, and the event loop dequeues
//! from the highest priority non-empty queue.
//!
//! ## Task Sources (WHATWG HTML Standard)
//!
//! - **UserInteraction**: User input events (click, keypress, etc.)
//! - **Networking**: Fetch responses, WebSocket messages
//! - **DOM**: DOM manipulation callbacks
//! - **Timer**: setTimeout, setInterval callbacks
//! - **Idle**: requestIdleCallback, background tasks
//!
//! ## Implementation
//!
//! Uses 5 separate FIFO queues with intrusive linked list for O(1) operations.
//! Dequeue selects from highest priority non-empty queue.
//!
//! ## References
//!
//! - WHATWG HTML Standard: Event loops
//! - https://html.spec.whatwg.org/multipage/webappapis.html#event-loops

const std = @import("std");

/// Task priority levels (higher value = lower priority)
pub const TaskPriority = enum(u8) {
    /// User interaction events - highest priority
    user_interaction = 0,
    /// Network/IO completions
    networking = 1,
    /// DOM manipulation callbacks
    dom = 2,
    /// Timer callbacks (setTimeout, setInterval)
    timer = 3,
    /// Idle callbacks - lowest priority
    idle = 4,

    pub const count = 5;
};

/// Task callback function type
pub const TaskCallback = *const fn (user_data: ?*anyopaque) void;

/// Intrusive task node for embedding in user structures
pub const TaskNode = struct {
    /// Next task in queue (intrusive linked list)
    next: ?*TaskNode = null,

    /// Task callback function
    callback: TaskCallback,

    /// User-provided context data
    user_data: ?*anyopaque = null,

    /// Task priority (for debugging/statistics)
    priority: TaskPriority = .timer,

    /// Initialize a task node
    pub fn init(callback: TaskCallback, user_data: ?*anyopaque, priority: TaskPriority) TaskNode {
        return .{
            .next = null,
            .callback = callback,
            .user_data = user_data,
            .priority = priority,
        };
    }

    /// Execute the task callback
    pub fn execute(self: *TaskNode) void {
        self.callback(self.user_data);
    }
};

/// Single FIFO queue using intrusive linked list
pub const TaskFifo = struct {
    head: ?*TaskNode = null,
    tail: ?*TaskNode = null,
    count: usize = 0,

    /// Enqueue a task (O(1))
    pub fn enqueue(self: *TaskFifo, task: *TaskNode) void {
        task.next = null;

        if (self.tail) |tail| {
            tail.next = task;
        } else {
            self.head = task;
        }
        self.tail = task;
        self.count += 1;
    }

    /// Dequeue a task (O(1))
    pub fn dequeue(self: *TaskFifo) ?*TaskNode {
        const head = self.head orelse return null;

        self.head = head.next;
        if (self.head == null) {
            self.tail = null;
        }
        self.count -= 1;

        head.next = null;
        return head;
    }

    /// Check if queue is empty
    pub fn isEmpty(self: *const TaskFifo) bool {
        return self.head == null;
    }

    /// Get number of tasks in queue
    pub fn len(self: *const TaskFifo) usize {
        return self.count;
    }
};

/// Priority-based task queue set
///
/// Contains one FIFO queue per priority level.
/// Dequeue returns task from highest priority non-empty queue.
pub const TaskQueueSet = struct {
    /// One queue per priority level
    queues: [TaskPriority.count]TaskFifo,

    /// Statistics
    total_enqueued: usize = 0,
    total_dequeued: usize = 0,

    const Self = @This();

    /// Initialize task queue set
    pub fn init() Self {
        return .{
            .queues = [_]TaskFifo{.{}} ** TaskPriority.count,
        };
    }

    /// Enqueue a task at specified priority (O(1))
    pub fn enqueue(self: *Self, task: *TaskNode, priority: TaskPriority) void {
        task.priority = priority;
        self.queues[@intFromEnum(priority)].enqueue(task);
        self.total_enqueued += 1;
    }

    /// Dequeue highest priority task (O(priorities))
    ///
    /// Iterates through priority levels from highest to lowest,
    /// returning the first task found. This is O(5) = O(1) since
    /// number of priorities is fixed.
    pub fn dequeue(self: *Self) ?*TaskNode {
        // Iterate from highest priority (0) to lowest (4)
        for (&self.queues) |*queue| {
            if (queue.dequeue()) |task| {
                self.total_dequeued += 1;
                return task;
            }
        }
        return null;
    }

    /// Dequeue from specific priority only
    pub fn dequeueFromPriority(self: *Self, priority: TaskPriority) ?*TaskNode {
        const task = self.queues[@intFromEnum(priority)].dequeue();
        if (task != null) {
            self.total_dequeued += 1;
        }
        return task;
    }

    /// Check if all queues are empty
    pub fn isEmpty(self: *const Self) bool {
        for (self.queues) |queue| {
            if (!queue.isEmpty()) return false;
        }
        return true;
    }

    /// Get total number of pending tasks
    pub fn pendingCount(self: *const Self) usize {
        var total: usize = 0;
        for (self.queues) |queue| {
            total += queue.len();
        }
        return total;
    }

    /// Get count for specific priority
    pub fn countForPriority(self: *const Self, priority: TaskPriority) usize {
        return self.queues[@intFromEnum(priority)].len();
    }

    /// Get statistics
    pub const Stats = struct {
        total_enqueued: usize,
        total_dequeued: usize,
        pending: usize,
        per_priority: [TaskPriority.count]usize,
    };

    pub fn getStats(self: *const Self) Stats {
        var per_priority: [TaskPriority.count]usize = undefined;
        for (self.queues, 0..) |queue, i| {
            per_priority[i] = queue.len();
        }

        return .{
            .total_enqueued = self.total_enqueued,
            .total_dequeued = self.total_dequeued,
            .pending = self.pendingCount(),
            .per_priority = per_priority,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TaskFifo - basic enqueue/dequeue" {
    var queue = TaskFifo{};

    var task1 = TaskNode.init(dummyCallback, null, .timer);
    var task2 = TaskNode.init(dummyCallback, null, .timer);
    var task3 = TaskNode.init(dummyCallback, null, .timer);

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), queue.len());

    queue.enqueue(&task1);
    try std.testing.expectEqual(@as(usize, 1), queue.len());

    queue.enqueue(&task2);
    queue.enqueue(&task3);
    try std.testing.expectEqual(@as(usize, 3), queue.len());

    // FIFO order
    try std.testing.expectEqual(&task1, queue.dequeue().?);
    try std.testing.expectEqual(&task2, queue.dequeue().?);
    try std.testing.expectEqual(&task3, queue.dequeue().?);
    try std.testing.expectEqual(@as(?*TaskNode, null), queue.dequeue());

    try std.testing.expect(queue.isEmpty());
}

test "TaskQueueSet - priority ordering" {
    var queue_set = TaskQueueSet.init();

    // Create tasks at different priorities
    var idle_task = TaskNode.init(dummyCallback, null, .idle);
    var timer_task = TaskNode.init(dummyCallback, null, .timer);
    var user_task = TaskNode.init(dummyCallback, null, .user_interaction);
    var network_task = TaskNode.init(dummyCallback, null, .networking);

    // Enqueue in random order
    queue_set.enqueue(&idle_task, .idle);
    queue_set.enqueue(&timer_task, .timer);
    queue_set.enqueue(&user_task, .user_interaction);
    queue_set.enqueue(&network_task, .networking);

    try std.testing.expectEqual(@as(usize, 4), queue_set.pendingCount());

    // Should dequeue in priority order (highest first)
    try std.testing.expectEqual(&user_task, queue_set.dequeue().?);
    try std.testing.expectEqual(&network_task, queue_set.dequeue().?);
    // DOM is empty, skip to timer
    try std.testing.expectEqual(&timer_task, queue_set.dequeue().?);
    try std.testing.expectEqual(&idle_task, queue_set.dequeue().?);
    try std.testing.expectEqual(@as(?*TaskNode, null), queue_set.dequeue());

    try std.testing.expect(queue_set.isEmpty());
}

test "TaskQueueSet - statistics" {
    var queue_set = TaskQueueSet.init();

    var task1 = TaskNode.init(dummyCallback, null, .timer);
    var task2 = TaskNode.init(dummyCallback, null, .user_interaction);

    queue_set.enqueue(&task1, .timer);
    queue_set.enqueue(&task2, .user_interaction);

    const stats1 = queue_set.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats1.total_enqueued);
    try std.testing.expectEqual(@as(usize, 0), stats1.total_dequeued);
    try std.testing.expectEqual(@as(usize, 2), stats1.pending);
    try std.testing.expectEqual(@as(usize, 1), stats1.per_priority[@intFromEnum(TaskPriority.timer)]);
    try std.testing.expectEqual(@as(usize, 1), stats1.per_priority[@intFromEnum(TaskPriority.user_interaction)]);

    _ = queue_set.dequeue();

    const stats2 = queue_set.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats2.total_enqueued);
    try std.testing.expectEqual(@as(usize, 1), stats2.total_dequeued);
    try std.testing.expectEqual(@as(usize, 1), stats2.pending);
}

test "TaskQueueSet - dequeueFromPriority" {
    var queue_set = TaskQueueSet.init();

    var timer_task = TaskNode.init(dummyCallback, null, .timer);
    var user_task = TaskNode.init(dummyCallback, null, .user_interaction);

    queue_set.enqueue(&timer_task, .timer);
    queue_set.enqueue(&user_task, .user_interaction);

    // Specifically dequeue from timer (not highest priority)
    try std.testing.expectEqual(&timer_task, queue_set.dequeueFromPriority(.timer).?);

    // User task still there
    try std.testing.expectEqual(&user_task, queue_set.dequeue().?);
}

test "TaskNode - execute callback" {
    var executed = false;
    var task = TaskNode.init(executionCallback, &executed, .timer);

    try std.testing.expect(!executed);
    task.execute();
    try std.testing.expect(executed);
}

fn dummyCallback(_: ?*anyopaque) void {}

fn executionCallback(user_data: ?*anyopaque) void {
    const flag: *bool = @ptrCast(@alignCast(user_data.?));
    flag.* = true;
}
