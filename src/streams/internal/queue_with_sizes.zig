//! Queue-with-sizes implementation per WHATWG Streams §8.1
//!
//! A queue-with-sizes is a List of value-with-size records,
//! accompanied by a number queueTotalSize.
//!
//! Spec: https://streams.spec.whatwg.org/#queue-with-sizes

const std = @import("std");
const common = @import("common");

/// Re-export JSValue as Value for compatibility
pub const Value = common.JSValue;

/// Value-with-size record
///
/// Spec: § 8.1 "A value-with-size is a struct with two items:"
pub const ValueWithSize = struct {
    /// value: any JavaScript value
    value: Value,
    /// size: a non-negative number (unrestricted double)
    size: f64,
};

/// Container with queue-with-sizes
///
/// Spec: § 8.1 "A container has a queue-with-sizes if it has..."
pub const QueueWithSizes = struct {
    allocator: std.mem.Allocator,
    /// [[queue]]: List of value-with-size records
    queue: std.ArrayList(ValueWithSize),
    /// [[queueTotalSize]]: Total size of all items in queue
    queue_total_size: f64,

    /// Initialize a new empty queue-with-sizes
    pub fn init(allocator: std.mem.Allocator) QueueWithSizes {
        return .{
            .allocator = allocator,
            .queue = .empty,
            .queue_total_size = 0.0,
        };
    }

    /// Deinitialize and free all resources
    pub fn deinit(self: *QueueWithSizes) void {
        self.queue.deinit(self.allocator);
    }

    /// DequeueValue(container) → value
    ///
    /// Spec: § 8.1 step 1 "DequeueValue(container) performs the following steps:"
    /// https://streams.spec.whatwg.org/#dequeue-value
    ///
    /// Dequeues and returns the first value from the queue.
    pub fn dequeueValue(self: *QueueWithSizes) !Value {
        // Step 1: Assert: container has [[queue]] and [[queueTotalSize]] internal slots.
        // (Implicit - type system enforces this)

        // Step 2: Assert: container.[[queue]] is not empty.
        if (self.queue.items.len == 0) return error.EmptyQueue;

        // Step 3: Let valueWithSize be container.[[queue]][0].
        const value_with_size = self.queue.items[0];

        // Step 4: Remove valueWithSize from container.[[queue]].
        _ = self.queue.orderedRemove(0);

        // Step 5: Set container.[[queueTotalSize]] to container.[[queueTotalSize]] − valueWithSize's size.
        self.queue_total_size -= value_with_size.size;

        // Step 6: If container.[[queueTotalSize]] < 0, set container.[[queueTotalSize]] to 0.
        if (self.queue_total_size < 0.0) {
            self.queue_total_size = 0.0;
        }

        // Step 7: Return valueWithSize's value.
        return value_with_size.value;
    }

    /// EnqueueValueWithSize(container, value, size)
    ///
    /// Spec: § 8.1 step 2 "EnqueueValueWithSize(container, value, size) performs the following steps:"
    /// https://streams.spec.whatwg.org/#enqueue-value-with-size
    ///
    /// Enqueues a value with its size.
    pub fn enqueueValueWithSize(
        self: *QueueWithSizes,
        value: Value,
        size: f64,
    ) !void {
        // Step 1: Assert: container has [[queue]] and [[queueTotalSize]] internal slots.
        // (Implicit - type system enforces this)

        // Step 2: If ! IsNonNegativeNumber(size) is false, throw a RangeError exception.
        if (std.math.isNan(size) or size < 0.0) {
            return error.RangeError;
        }

        // Step 3: If size is +∞, throw a RangeError exception.
        if (std.math.isInf(size)) {
            return error.RangeError;
        }

        // Step 4: Append a new value-with-size with value value and size size to container.[[queue]].
        try self.queue.append(self.allocator, .{
            .value = value,
            .size = size,
        });

        // Step 5: Set container.[[queueTotalSize]] to container.[[queueTotalSize]] + size.
        self.queue_total_size += size;
    }

    /// PeekQueueValue(container) → value
    ///
    /// Spec: § 8.1 step 3 "PeekQueueValue(container) performs the following steps:"
    /// https://streams.spec.whatwg.org/#peek-queue-value
    ///
    /// Returns the first value without removing it.
    pub fn peekQueueValue(self: *const QueueWithSizes) !Value {
        // Step 1: Assert: container has [[queue]] and [[queueTotalSize]] internal slots.
        // (Implicit - type system enforces this)

        // Step 2: Assert: container.[[queue]] is not empty.
        if (self.queue.items.len == 0) return error.EmptyQueue;

        // Step 3: Let valueWithSize be container.[[queue]][0].
        const value_with_size = self.queue.items[0];

        // Step 4: Return valueWithSize's value.
        return value_with_size.value;
    }

    /// ResetQueue(container)
    ///
    /// Spec: § 8.1 step 4 "ResetQueue(container) performs the following steps:"
    /// https://streams.spec.whatwg.org/#reset-queue
    ///
    /// Clears the queue and resets total size to zero.
    pub fn resetQueue(self: *QueueWithSizes) void {
        // Step 1: Assert: container has [[queue]] and [[queueTotalSize]] internal slots.
        // (Implicit - type system enforces this)

        // Step 2: Set container.[[queue]] to a new empty list.
        self.queue.clearRetainingCapacity();

        // Step 3: Set container.[[queueTotalSize]] to 0.
        self.queue_total_size = 0.0;
    }

    /// Check if queue is empty
    pub fn isEmpty(self: *const QueueWithSizes) bool {
        return self.queue.items.len == 0;
    }

    /// Get the number of items in the queue
    pub fn len(self: *const QueueWithSizes) usize {
        return self.queue.items.len;
    }
};

// Tests

test "QueueWithSizes - init and deinit" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    try std.testing.expectEqual(@as(usize, 0), queue.len());
    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(f64, 0.0), queue.queue_total_size);
}

test "QueueWithSizes - enqueue and dequeue single item" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    // Enqueue a value
    const value = Value{ .number = 42.0 };
    try queue.enqueueValueWithSize(value, 1.0);

    try std.testing.expectEqual(@as(usize, 1), queue.len());
    try std.testing.expectEqual(@as(f64, 1.0), queue.queue_total_size);

    // Dequeue the value
    const dequeued = try queue.dequeueValue();
    try std.testing.expectEqual(value, dequeued);
    try std.testing.expectEqual(@as(usize, 0), queue.len());
    try std.testing.expectEqual(@as(f64, 0.0), queue.queue_total_size);
}

test "QueueWithSizes - enqueue multiple items with different sizes" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    try queue.enqueueValueWithSize(.{ .number = 1.0 }, 10.0);
    try queue.enqueueValueWithSize(.{ .number = 2.0 }, 20.0);
    try queue.enqueueValueWithSize(.{ .number = 3.0 }, 30.0);

    try std.testing.expectEqual(@as(usize, 3), queue.len());
    try std.testing.expectEqual(@as(f64, 60.0), queue.queue_total_size);

    // Dequeue in FIFO order
    const v1 = try queue.dequeueValue();
    try std.testing.expectEqual(Value{ .number = 1.0 }, v1);
    try std.testing.expectEqual(@as(f64, 50.0), queue.queue_total_size);

    const v2 = try queue.dequeueValue();
    try std.testing.expectEqual(Value{ .number = 2.0 }, v2);
    try std.testing.expectEqual(@as(f64, 30.0), queue.queue_total_size);

    const v3 = try queue.dequeueValue();
    try std.testing.expectEqual(Value{ .number = 3.0 }, v3);
    try std.testing.expectEqual(@as(f64, 0.0), queue.queue_total_size);
}

test "QueueWithSizes - peek does not remove item" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    try queue.enqueueValueWithSize(.{ .number = 42.0 }, 1.0);

    // Peek multiple times
    const peeked1 = try queue.peekQueueValue();
    try std.testing.expectEqual(Value{ .number = 42.0 }, peeked1);
    try std.testing.expectEqual(@as(usize, 1), queue.len());

    const peeked2 = try queue.peekQueueValue();
    try std.testing.expectEqual(Value{ .number = 42.0 }, peeked2);
    try std.testing.expectEqual(@as(usize, 1), queue.len());

    // Dequeue still works
    const dequeued = try queue.dequeueValue();
    try std.testing.expectEqual(Value{ .number = 42.0 }, dequeued);
    try std.testing.expectEqual(@as(usize, 0), queue.len());
}

test "QueueWithSizes - resetQueue clears everything" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    try queue.enqueueValueWithSize(.{ .number = 1.0 }, 10.0);
    try queue.enqueueValueWithSize(.{ .number = 2.0 }, 20.0);

    queue.resetQueue();

    try std.testing.expectEqual(@as(usize, 0), queue.len());
    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(f64, 0.0), queue.queue_total_size);
}

test "QueueWithSizes - dequeue on empty queue returns error" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    try std.testing.expectError(error.EmptyQueue, queue.dequeueValue());
}

test "QueueWithSizes - peek on empty queue returns error" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    try std.testing.expectError(error.EmptyQueue, queue.peekQueueValue());
}

test "QueueWithSizes - enqueue with negative size returns error" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    try std.testing.expectError(error.RangeError, queue.enqueueValueWithSize(.{ .number = 1.0 }, -1.0));
}

test "QueueWithSizes - enqueue with NaN size returns error" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    try std.testing.expectError(error.RangeError, queue.enqueueValueWithSize(.{ .number = 1.0 }, std.math.nan(f64)));
}

test "QueueWithSizes - enqueue with infinite size returns error" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    try std.testing.expectError(error.RangeError, queue.enqueueValueWithSize(.{ .number = 1.0 }, std.math.inf(f64)));
}

test "QueueWithSizes - negative total size clamped to zero" {
    const allocator = std.testing.allocator;

    var queue = QueueWithSizes.init(allocator);
    defer queue.deinit();

    // Enqueue with small size
    try queue.enqueueValueWithSize(.{ .number = 1.0 }, 0.1);
    try std.testing.expectEqual(@as(f64, 0.1), queue.queue_total_size);

    // Manually set a larger size to trigger clamping
    queue.queue.items[0].size = 0.2;

    // Dequeue should clamp to 0
    _ = try queue.dequeueValue();
    try std.testing.expectEqual(@as(f64, 0.0), queue.queue_total_size);
}
