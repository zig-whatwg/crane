//! I/O Queue Implementation
//!
//! WHATWG Encoding Standard §3
//! https://encoding.spec.whatwg.org/#i/o-queue
//!
//! An I/O queue is a type of list with items of a particular type
//! (i.e., bytes or scalar values). End-of-queue is a special item
//! that can be present in I/O queues of any type and it signifies
//! that there are no more items in the queue.
//!
//! Uses WHATWG Infra's List primitive.

const std = @import("std");
const infra = @import("infra");
const List = infra.List;
const Allocator = std.mem.Allocator;

/// Special marker for end-of-queue
/// Uses a sentinel value that won't appear in normal byte/code point streams
pub const END_OF_QUEUE: u32 = 0xFFFFFFFF;

/// I/O queue for bytes (u8)
pub const ByteQueue = IoQueue(u8);

/// I/O queue for scalar values (code points)
pub const ScalarQueue = IoQueue(u21);

/// Generic I/O queue implementation using Infra List
///
/// Spec: https://encoding.spec.whatwg.org/#i/o-queue
pub fn IoQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Underlying Infra list
        items: List(Item),

        /// Current read position
        read_pos: usize,

        /// Whether end-of-queue marker has been added
        has_end_marker: bool,

        /// Item type with end-of-queue support
        pub const Item = union(enum) {
            value: T,
            end_of_queue: void,

            pub fn isEndOfQueue(self: Item) bool {
                return self == .end_of_queue;
            }
        };

        /// Initialize an empty I/O queue
        pub fn init(allocator: Allocator) Self {
            return Self{
                .items = List(Item).init(allocator),
                .read_pos = 0,
                .has_end_marker = false,
            };
        }

        /// Create I/O queue from a slice
        pub fn fromSlice(allocator: Allocator, data: []const T) !Self {
            var self = Self.init(allocator);

            for (data) |byte| {
                try self.items.append(.{ .value = byte });
            }

            return self;
        }

        /// Deinitialize the queue
        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        /// Read an item from the queue
        ///
        /// Spec: https://encoding.spec.whatwg.org/#concept-stream-read
        ///
        /// To read an item from an I/O queue ioQueue:
        /// 1. If ioQueue is empty, then wait until it is not empty.
        /// 2. If ioQueue[0] is end-of-queue, then return end-of-queue.
        /// 3. Remove ioQueue[0] and return it.
        pub fn read(self: *Self) ?Item {
            // Step 1: If queue is empty (all items consumed), return null
            // In streaming mode, caller should wait for more data
            if (self.read_pos >= self.items.size()) {
                return null;
            }

            // Step 2: Peek at next item
            const item = self.items.get(self.read_pos) orelse return null;

            // Step 2: If end-of-queue, return it (don't consume)
            if (item.isEndOfQueue()) {
                return item;
            }

            // Step 3: Remove and return item
            self.read_pos += 1;
            return item;
        }

        /// Peek at the next item without consuming it
        ///
        /// Spec: https://encoding.spec.whatwg.org/#concept-stream-peek
        ///
        /// Returns the next item without advancing read position
        pub fn peekNext(self: *const Self) ?Item {
            if (self.read_pos >= self.items.size()) {
                return null;
            }

            return self.items.get(self.read_pos);
        }

        /// Push an item to the end of the queue
        ///
        /// Spec: https://encoding.spec.whatwg.org/#concept-stream-push
        ///
        /// To push an item item to an I/O queue ioQueue:
        /// 1. If ioQueue's last item is end-of-queue, remove ioQueue's last item.
        /// 2. Otherwise, append item to ioQueue.
        pub fn push(self: *Self, value: T) !void {
            // Step 1: Check if last item is end-of-queue
            if (self.has_end_marker and self.items.size() > 0) {
                const last_idx = self.items.size() - 1;
                if (self.items.get(last_idx)) |last_item| {
                    if (last_item.isEndOfQueue()) {
                        // Remove end marker, append value, re-add end marker
                        _ = try self.items.remove(last_idx);
                        try self.items.append(.{ .value = value });
                        try self.items.append(.{ .end_of_queue = {} });
                        return;
                    }
                }
            }

            // Step 2: Append item
            try self.items.append(.{ .value = value });
        }

        /// Restore (prepend) an item to the beginning of the queue
        ///
        /// Spec: https://encoding.spec.whatwg.org/#concept-stream-prepend
        ///
        /// To restore an item to an I/O queue, perform the list prepend operation.
        pub fn restore(self: *Self, value: T) !void {
            // If we haven't consumed any items yet, prepend to the list
            if (self.read_pos == 0) {
                try self.items.prepend(.{ .value = value });
            } else {
                // Otherwise, we can "unread" by decrementing read position
                // and setting the item at that position
                self.read_pos -= 1;
                _ = try self.items.replace(self.read_pos, .{ .value = value });
            }
        }

        /// Add end-of-queue marker
        ///
        /// This is called when no more data will be added (streaming complete)
        pub fn markEnd(self: *Self) !void {
            if (!self.has_end_marker) {
                try self.items.append(.{ .end_of_queue = {} });
                self.has_end_marker = true;
            }
        }

        /// Check if queue is empty (all items consumed)
        pub fn isEmpty(self: *const Self) bool {
            return self.read_pos >= self.items.size();
        }

        /// Get remaining items count
        pub fn remaining(self: *const Self) usize {
            if (self.read_pos >= self.items.size()) return 0;
            return self.items.size() - self.read_pos;
        }

        /// Convert remaining queue contents to a slice (for debugging)
        pub fn toSlice(self: *Self, allocator: Allocator) ![]T {
            // Count items first
            var count: usize = 0;
            var i = self.read_pos;
            while (i < self.items.size()) : (i += 1) {
                if (self.items.get(i)) |item| {
                    if (item.isEndOfQueue()) break;
                    count += 1;
                }
            }

            // Allocate slice
            const result = try allocator.alloc(T, count);
            errdefer allocator.free(result);

            // Fill slice
            var idx: usize = 0;
            i = self.read_pos;
            while (i < self.items.size() and idx < count) : (i += 1) {
                if (self.items.get(i)) |item| {
                    switch (item) {
                        .value => |v| {
                            result[idx] = v;
                            idx += 1;
                        },
                        .end_of_queue => break,
                    }
                }
            }

            return result;
        }
    };
}

// Tests

test "IoQueue - basic operations" {
    const allocator = std.testing.allocator;

    var queue = ByteQueue.init(allocator);
    defer queue.deinit();

    // Push some bytes
    try queue.push(0x41); // 'A'
    try queue.push(0x42); // 'B'
    try queue.push(0x43); // 'C'

    // Read them back
    const item1 = queue.read().?;
    try std.testing.expect(item1 == .value);
    try std.testing.expectEqual(@as(u8, 0x41), item1.value);

    const item2 = queue.read().?;
    try std.testing.expectEqual(@as(u8, 0x42), item2.value);

    const item3 = queue.read().?;
    try std.testing.expectEqual(@as(u8, 0x43), item3.value);

    // Queue should be empty now
    try std.testing.expect(queue.isEmpty());
}

test "IoQueue - restore" {
    const allocator = std.testing.allocator;

    var queue = ByteQueue.init(allocator);
    defer queue.deinit();

    try queue.push(0x41);
    try queue.push(0x42);

    // Read first byte
    const item1 = queue.read().?;
    try std.testing.expectEqual(@as(u8, 0x41), item1.value);

    // Restore it
    try queue.restore(0x41);

    // Should read it again
    const item2 = queue.read().?;
    try std.testing.expectEqual(@as(u8, 0x41), item2.value);

    // Then the second byte
    const item3 = queue.read().?;
    try std.testing.expectEqual(@as(u8, 0x42), item3.value);
}

test "IoQueue - end-of-queue marker" {
    const allocator = std.testing.allocator;

    var queue = ByteQueue.init(allocator);
    defer queue.deinit();

    try queue.push(0x41);
    try queue.markEnd();

    // Read the byte
    const item1 = queue.read().?;
    try std.testing.expectEqual(@as(u8, 0x41), item1.value);

    // Should get end-of-queue
    const item2 = queue.read().?;
    try std.testing.expect(item2.isEndOfQueue());
}

test "IoQueue - fromSlice" {
    const allocator = std.testing.allocator;

    const data = [_]u8{ 0x48, 0x65, 0x6C, 0x6C, 0x6F }; // "Hello"
    var queue = try ByteQueue.fromSlice(allocator, &data);
    defer queue.deinit();

    try std.testing.expectEqual(@as(usize, 5), queue.remaining());

    const item = queue.read().?;
    try std.testing.expectEqual(@as(u8, 0x48), item.value);
}

test "IoQueue - push with end marker" {
    const allocator = std.testing.allocator;

    var queue = ByteQueue.init(allocator);
    defer queue.deinit();

    try queue.push(0x41);
    try queue.markEnd();

    // Pushing after end marker should remove it, add item, and re-add marker
    try queue.push(0x42);

    const item1 = queue.read().?;
    try std.testing.expectEqual(@as(u8, 0x41), item1.value);

    const item2 = queue.read().?;
    try std.testing.expectEqual(@as(u8, 0x42), item2.value);

    // End marker should still be there
    const end = queue.read().?;
    try std.testing.expect(end.isEndOfQueue());
}
