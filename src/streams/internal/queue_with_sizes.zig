//! Queue-with-sizes implementation per WHATWG Streams §8.1
//!
//! A queue-with-sizes is a List of value-with-size records,
//! accompanied by a number queueTotalSize.
//!
//! Spec: https://streams.spec.whatwg.org/#queue-with-sizes

const std = @import("std");
const infra = @import("infra");
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
    queue: infra.List(ValueWithSize),
    /// [[queueTotalSize]]: Total size of all items in queue
    queue_total_size: f64,

    /// Initialize a new empty queue-with-sizes
    pub fn init(allocator: std.mem.Allocator) QueueWithSizes {
        return .{
            .allocator = allocator,
            .queue = infra.List(ValueWithSize).init(allocator),
            .queue_total_size = 0.0,
        };
    }

    /// Deinitialize and free all resources
    pub fn deinit(self: *QueueWithSizes) void {
        self.queue.deinit();
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
        if (self.queue.len == 0) return error.EmptyQueue;

        // Step 3: Let valueWithSize be container.[[queue]][0].
        const value_with_size = self.queue.get(0).?;

        // Step 4: Remove valueWithSize from container.[[queue]].
        _ = try self.queue.remove(0);

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
        try self.queue.append(.{
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
        if (self.queue.len == 0) return error.EmptyQueue;

        // Step 3: Let valueWithSize be container.[[queue]][0].
        const value_with_size = self.queue.get(0).?;

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
        self.queue.clear();

        // Step 3: Set container.[[queueTotalSize]] to 0.
        self.queue_total_size = 0.0;
    }

    /// Check if queue is empty
    pub fn isEmpty(self: *const QueueWithSizes) bool {
        return self.queue.len == 0;
    }

    /// Get the number of items in the queue
    pub fn len(self: *const QueueWithSizes) usize {
        return self.queue.len;
    }
};

// Tests











