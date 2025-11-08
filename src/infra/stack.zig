//! WHATWG Infra Stack Operations
//!
//! Spec: https://infra.spec.whatwg.org/#stack
//!
//! A stack is a LIFO (last-in, first-out) data structure.

const std = @import("std");
const Allocator = std.mem.Allocator;
const List = @import("list.zig").List;

pub fn Stack(comptime T: type) type {
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

        pub fn push(self: *Self, item: T) !void {
            try self.items_list.append(item);
        }

        pub fn pop(self: *Self) ?T {
            if (self.items_list.isEmpty()) return null;
            return self.items_list.remove(self.items_list.size() - 1) catch unreachable;
        }

        pub fn peek(self: *const Self) ?T {
            if (self.items_list.isEmpty()) return null;
            return self.items_list.get(self.items_list.size() - 1);
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.items_list.isEmpty();
        }
    };
}

test "Stack - push and pop" {
    const allocator = std.testing.allocator;
    var stack = Stack(u32).init(allocator);
    defer stack.deinit();

    try stack.push(1);
    try stack.push(2);
    try stack.push(3);

    try std.testing.expectEqual(@as(?u32, 3), stack.pop());
    try std.testing.expectEqual(@as(?u32, 2), stack.pop());
    try std.testing.expectEqual(@as(?u32, 1), stack.pop());
}

test "Stack - pop empty returns null" {
    const allocator = std.testing.allocator;
    var stack = Stack(u32).init(allocator);
    defer stack.deinit();

    try std.testing.expectEqual(@as(?u32, null), stack.pop());
}

test "Stack - peek" {
    const allocator = std.testing.allocator;
    var stack = Stack(u32).init(allocator);
    defer stack.deinit();

    try stack.push(1);
    try stack.push(2);

    try std.testing.expectEqual(@as(?u32, 2), stack.peek());
    try std.testing.expectEqual(@as(?u32, 2), stack.peek());
}

test "Stack - isEmpty" {
    const allocator = std.testing.allocator;
    var stack = Stack(u32).init(allocator);
    defer stack.deinit();

    try std.testing.expect(stack.isEmpty());
    try stack.push(1);
    try std.testing.expect(!stack.isEmpty());
}

test "Stack - LIFO order" {
    const allocator = std.testing.allocator;
    var stack = Stack(u32).init(allocator);
    defer stack.deinit();

    try stack.push(10);
    try stack.push(20);
    try stack.push(30);

    try std.testing.expectEqual(@as(?u32, 30), stack.pop());
    try std.testing.expectEqual(@as(?u32, 20), stack.pop());
    try std.testing.expectEqual(@as(?u32, 10), stack.pop());
}

test "Stack - no memory leaks" {
    const allocator = std.testing.allocator;
    var stack = Stack(u32).init(allocator);
    defer stack.deinit();

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        try stack.push(i);
    }
}
