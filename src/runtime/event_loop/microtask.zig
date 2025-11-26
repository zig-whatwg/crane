//! Microtask Queue for WHATWG Event Loop
//!
//! Implements the microtask queue as defined in the WHATWG HTML Standard.
//! Microtasks are processed during microtask checkpoints, draining the
//! entire queue before returning to the event loop.
//!
//! ## Microtask Sources
//!
//! - Promise reactions (resolve/reject handlers)
//! - MutationObserver callbacks
//! - queueMicrotask() API
//!
//! ## Processing Model
//!
//! During a microtask checkpoint:
//! 1. While microtask queue is not empty:
//!    a. Dequeue oldest microtask
//!    b. Execute microtask
//!    c. (May enqueue more microtasks)
//! 2. Repeat until queue is empty
//!
//! ## References
//!
//! - WHATWG HTML Standard: Microtask queuing
//! - https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint

const std = @import("std");

/// Microtask callback function type
pub const MicrotaskCallback = *const fn (user_data: ?*anyopaque) void;

/// Intrusive microtask node
pub const MicrotaskNode = struct {
    /// Next microtask in queue (intrusive linked list)
    next: ?*MicrotaskNode = null,

    /// Microtask callback function
    callback: MicrotaskCallback,

    /// User-provided context data
    user_data: ?*anyopaque = null,

    /// Initialize a microtask node
    pub fn init(callback: MicrotaskCallback, user_data: ?*anyopaque) MicrotaskNode {
        return .{
            .next = null,
            .callback = callback,
            .user_data = user_data,
        };
    }

    /// Execute the microtask callback
    pub fn execute(self: *MicrotaskNode) void {
        self.callback(self.user_data);
    }
};

/// Microtask queue (FIFO)
///
/// Implements the microtask queue with checkpoint semantics.
/// The queue is drained completely during each checkpoint.
pub const MicrotaskQueue = struct {
    head: ?*MicrotaskNode = null,
    tail: ?*MicrotaskNode = null,
    count: usize = 0,

    /// Flag to detect re-entrant checkpoint calls
    performing_checkpoint: bool = false,

    /// Statistics
    total_enqueued: usize = 0,
    total_executed: usize = 0,
    max_depth: usize = 0,

    const Self = @This();

    /// Initialize microtask queue
    pub fn init() Self {
        return .{};
    }

    /// Enqueue a microtask (O(1))
    ///
    /// Can be called during microtask execution (nested microtasks).
    pub fn enqueue(self: *Self, microtask: *MicrotaskNode) void {
        microtask.next = null;

        if (self.tail) |tail| {
            tail.next = microtask;
        } else {
            self.head = microtask;
        }
        self.tail = microtask;
        self.count += 1;
        self.total_enqueued += 1;

        if (self.count > self.max_depth) {
            self.max_depth = self.count;
        }
    }

    /// Dequeue a microtask (O(1))
    fn dequeue(self: *Self) ?*MicrotaskNode {
        const head = self.head orelse return null;

        self.head = head.next;
        if (self.head == null) {
            self.tail = null;
        }
        self.count -= 1;

        head.next = null;
        return head;
    }

    /// Perform microtask checkpoint
    ///
    /// Drains the entire microtask queue, executing each microtask.
    /// Microtasks enqueued during execution are also processed.
    ///
    /// Returns the number of microtasks executed.
    pub fn performCheckpoint(self: *Self) usize {
        // Prevent re-entrant checkpoint calls
        if (self.performing_checkpoint) {
            return 0;
        }

        self.performing_checkpoint = true;
        defer self.performing_checkpoint = false;

        var executed: usize = 0;

        // Drain queue completely (including nested microtasks)
        while (self.dequeue()) |microtask| {
            microtask.execute();
            executed += 1;
            self.total_executed += 1;
        }

        return executed;
    }

    /// Check if queue is empty
    pub fn isEmpty(self: *const Self) bool {
        return self.head == null;
    }

    /// Get number of pending microtasks
    pub fn len(self: *const Self) usize {
        return self.count;
    }

    /// Check if currently in a checkpoint
    pub fn isPerformingCheckpoint(self: *const Self) bool {
        return self.performing_checkpoint;
    }

    /// Get statistics
    pub const Stats = struct {
        pending: usize,
        total_enqueued: usize,
        total_executed: usize,
        max_depth: usize,
    };

    pub fn getStats(self: *const Self) Stats {
        return .{
            .pending = self.count,
            .total_enqueued = self.total_enqueued,
            .total_executed = self.total_executed,
            .max_depth = self.max_depth,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "MicrotaskQueue - basic enqueue/checkpoint" {
    var queue = MicrotaskQueue.init();

    var executed_count: usize = 0;
    var task1 = MicrotaskNode.init(countingCallback, &executed_count);
    var task2 = MicrotaskNode.init(countingCallback, &executed_count);
    var task3 = MicrotaskNode.init(countingCallback, &executed_count);

    try std.testing.expect(queue.isEmpty());

    queue.enqueue(&task1);
    queue.enqueue(&task2);
    queue.enqueue(&task3);

    try std.testing.expectEqual(@as(usize, 3), queue.len());
    try std.testing.expectEqual(@as(usize, 0), executed_count);

    const executed = queue.performCheckpoint();

    try std.testing.expectEqual(@as(usize, 3), executed);
    try std.testing.expectEqual(@as(usize, 3), executed_count);
    try std.testing.expect(queue.isEmpty());
}

test "MicrotaskQueue - nested microtasks" {
    var queue = MicrotaskQueue.init();

    // Setup: task1 will enqueue task2 when executed
    var context = NestingContext{
        .queue = &queue,
        .executed_order = [_]usize{0} ** 10,
        .executed_count = 0,
    };

    var task1 = MicrotaskNode.init(nestingCallback, &context);
    queue.enqueue(&task1);

    // After checkpoint, both task1 and nested task2 should have executed
    const executed = queue.performCheckpoint();

    try std.testing.expectEqual(@as(usize, 2), executed);
    try std.testing.expectEqual(@as(usize, 2), context.executed_count);
    // Order: task1 (1), nested task2 (2)
    try std.testing.expectEqual(@as(usize, 1), context.executed_order[0]);
    try std.testing.expectEqual(@as(usize, 2), context.executed_order[1]);
}

test "MicrotaskQueue - statistics" {
    var queue = MicrotaskQueue.init();

    var counter: usize = 0;
    var task1 = MicrotaskNode.init(countingCallback, &counter);
    var task2 = MicrotaskNode.init(countingCallback, &counter);

    queue.enqueue(&task1);
    queue.enqueue(&task2);

    const stats1 = queue.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats1.pending);
    try std.testing.expectEqual(@as(usize, 2), stats1.total_enqueued);
    try std.testing.expectEqual(@as(usize, 0), stats1.total_executed);
    try std.testing.expectEqual(@as(usize, 2), stats1.max_depth);

    _ = queue.performCheckpoint();

    const stats2 = queue.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats2.pending);
    try std.testing.expectEqual(@as(usize, 2), stats2.total_enqueued);
    try std.testing.expectEqual(@as(usize, 2), stats2.total_executed);
}

test "MicrotaskQueue - empty checkpoint" {
    var queue = MicrotaskQueue.init();

    const executed = queue.performCheckpoint();
    try std.testing.expectEqual(@as(usize, 0), executed);
}

// Test helpers

fn countingCallback(user_data: ?*anyopaque) void {
    const count: *usize = @ptrCast(@alignCast(user_data.?));
    count.* += 1;
}

const NestingContext = struct {
    queue: *MicrotaskQueue,
    executed_order: [10]usize,
    executed_count: usize,
    nested_task: MicrotaskNode = undefined,
};

fn nestingCallback(user_data: ?*anyopaque) void {
    const ctx: *NestingContext = @ptrCast(@alignCast(user_data.?));

    ctx.executed_count += 1;
    ctx.executed_order[ctx.executed_count - 1] = ctx.executed_count;

    // Enqueue a nested task on first execution
    if (ctx.executed_count == 1) {
        ctx.nested_task = MicrotaskNode.init(nestedTaskCallback, ctx);
        ctx.queue.enqueue(&ctx.nested_task);
    }
}

fn nestedTaskCallback(user_data: ?*anyopaque) void {
    const ctx: *NestingContext = @ptrCast(@alignCast(user_data.?));
    ctx.executed_count += 1;
    ctx.executed_order[ctx.executed_count - 1] = ctx.executed_count;
}
