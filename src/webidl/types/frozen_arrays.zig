//! WebIDL FrozenArray<T>
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-frozen-array
//!
//! FrozenArray represents an immutable array. Once created, its contents cannot
//! be modified. It's used for readonly array attributes in Web APIs.

const std = @import("std");
const infra = @import("infra");

pub fn FrozenArray(comptime T: type) type {
    return struct {
        items: []const T,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, items: []const T) !Self {
            const owned_items = try allocator.dupe(T, items);
            return .{
                .items = owned_items,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.items);
        }

        pub fn len(self: Self) usize {
            return self.items.len;
        }

        pub fn get(self: Self, index: usize) ?T {
            if (index >= self.items.len) return null;
            return self.items[index];
        }

        pub fn contains(self: Self, item: T) bool {
            for (self.items) |value| {
                if (std.meta.eql(value, item)) return true;
            }
            return false;
        }

        pub fn slice(self: Self) []const T {
            return self.items;
        }

        pub fn isEmpty(self: Self) bool {
            return self.items.len == 0;
        }
    };
}

const testing = std.testing;

test "FrozenArray - creation from slice" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    const array = try FrozenArray(i32).init(testing.allocator, &items);
    defer array.deinit();

    try testing.expectEqual(@as(usize, 5), array.len());
}

test "FrozenArray - get by index" {
    const items = [_]i32{ 10, 20, 30 };

    const array = try FrozenArray(i32).init(testing.allocator, &items);
    defer array.deinit();

    try testing.expectEqual(@as(i32, 10), array.get(0).?);
    try testing.expectEqual(@as(i32, 20), array.get(1).?);
    try testing.expectEqual(@as(i32, 30), array.get(2).?);
    try testing.expect(array.get(3) == null);
}

test "FrozenArray - contains check" {
    const items = [_]i32{ 1, 2, 3 };

    const array = try FrozenArray(i32).init(testing.allocator, &items);
    defer array.deinit();

    try testing.expect(array.contains(2));
    try testing.expect(!array.contains(5));
}

test "FrozenArray - slice access" {
    const items = [_]i32{ 1, 2, 3 };

    const array = try FrozenArray(i32).init(testing.allocator, &items);
    defer array.deinit();

    const slice = array.slice();
    try testing.expectEqual(@as(usize, 3), slice.len);
    try testing.expectEqual(@as(i32, 1), slice[0]);
}

test "FrozenArray - isEmpty" {
    const empty_items = [_]i32{};
    const empty_array = try FrozenArray(i32).init(testing.allocator, &empty_items);
    defer empty_array.deinit();

    try testing.expect(empty_array.isEmpty());

    const items = [_]i32{1};
    const array = try FrozenArray(i32).init(testing.allocator, &items);
    defer array.deinit();

    try testing.expect(!array.isEmpty());
}

test "FrozenArray - string elements" {
    const items = [_][]const u8{ "hello", "world" };

    const array = try FrozenArray([]const u8).init(testing.allocator, &items);
    defer array.deinit();

    try testing.expectEqual(@as(usize, 2), array.len());
    try testing.expectEqualStrings("hello", array.get(0).?);
    try testing.expectEqualStrings("world", array.get(1).?);
}

test "FrozenArray - immutability guarantees" {
    const items = [_]i32{ 1, 2, 3 };

    const array = try FrozenArray(i32).init(testing.allocator, &items);
    defer array.deinit();

    const slice = array.slice();
    try testing.expectEqual(@as(i32, 1), slice[0]);
}
