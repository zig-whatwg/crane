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






