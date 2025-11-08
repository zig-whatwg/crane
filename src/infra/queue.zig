//! WHATWG Infra Queue Operations
//!
//! Spec: https://infra.spec.whatwg.org/#queue
//!
//! A queue is a FIFO (first-in, first-out) data structure.

const std = @import("std");
const Allocator = std.mem.Allocator;
const List = @import("list.zig").List;

pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();

        items_list: List(T),

        pub fn init(allocator: Allocator) Self {
            return Self{
                .items_list = List(T).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.items_list.deinit();
        }

        pub fn enqueue(self: *Self, item: T) !void {
            try self.items_list.append(item);
        }

        pub fn dequeue(self: *Self) ?T {
            if (self.items_list.isEmpty()) return null;
            return self.items_list.remove(0) catch unreachable;
        }

        pub fn peek(self: *const Self) ?T {
            if (self.items_list.isEmpty()) return null;
            return self.items_list.get(0);
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.items_list.isEmpty();
        }
    };
}

test "Queue - enqueue and dequeue" {
    const allocator = std.testing.allocator;
    var queue = Queue(u32).init(allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);

    try std.testing.expectEqual(@as(?u32, 1), queue.dequeue());
    try std.testing.expectEqual(@as(?u32, 2), queue.dequeue());
    try std.testing.expectEqual(@as(?u32, 3), queue.dequeue());
}

test "Queue - dequeue empty returns null" {
    const allocator = std.testing.allocator;
    var queue = Queue(u32).init(allocator);
    defer queue.deinit();

    try std.testing.expectEqual(@as(?u32, null), queue.dequeue());
}

test "Queue - peek" {
    const allocator = std.testing.allocator;
    var queue = Queue(u32).init(allocator);
    defer queue.deinit();

    try queue.enqueue(1);
    try queue.enqueue(2);

    try std.testing.expectEqual(@as(?u32, 1), queue.peek());
    try std.testing.expectEqual(@as(?u32, 1), queue.peek());
}

test "Queue - isEmpty" {
    const allocator = std.testing.allocator;
    var queue = Queue(u32).init(allocator);
    defer queue.deinit();

    try std.testing.expect(queue.isEmpty());
    try queue.enqueue(1);
    try std.testing.expect(!queue.isEmpty());
}

test "Queue - FIFO order" {
    const allocator = std.testing.allocator;
    var queue = Queue(u32).init(allocator);
    defer queue.deinit();

    try queue.enqueue(10);
    try queue.enqueue(20);
    try queue.enqueue(30);

    try std.testing.expectEqual(@as(?u32, 10), queue.dequeue());
    try std.testing.expectEqual(@as(?u32, 20), queue.dequeue());
    try std.testing.expectEqual(@as(?u32, 30), queue.dequeue());
}

test "Queue - no memory leaks" {
    const allocator = std.testing.allocator;
    var queue = Queue(u32).init(allocator);
    defer queue.deinit();

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        try queue.enqueue(i);
    }
}
