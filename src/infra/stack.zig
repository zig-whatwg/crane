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






