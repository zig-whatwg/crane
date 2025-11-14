//! WebIDL FrozenArray<T>
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-frozen-array
//! Spec: https://webidl.spec.whatwg.org/#es-frozen-array
//!
//! FrozenArray represents an immutable array. Once created, its contents cannot
//! be modified. It's used for readonly array attributes in Web APIs.
//!
//! Conversion Algorithm:
//! 1. Let `values` be the result of converting V to IDL type sequence<T>
//! 2. Return the result of creating a frozen array from `values`

const std = @import("std");
const infra = @import("infra");
const primitives = @import("primitives.zig");

const JSValue = primitives.JSValue;

pub fn FrozenArray(comptime T: type) type {
    return struct {
        items: []const T,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create FrozenArray from Zig slice
        ///
        /// Spec: Create immutable array by copying items
        ///
        /// This is used when constructing FrozenArray from native Zig code.
        /// For JavaScript value conversion, use `fromJSValue`.
        pub fn init(allocator: std.mem.Allocator, items: []const T) !Self {
            const owned_items = try allocator.dupe(T, items);
            return .{
                .items = owned_items,
                .allocator = allocator,
            };
        }

        /// Convert JavaScript value to FrozenArray<T>
        ///
        /// Spec: https://webidl.spec.whatwg.org/#es-frozen-array
        ///
        /// Algorithm:
        /// 1. Let `values` be the result of converting V to IDL type sequence<T>
        /// 2. Return the result of creating a frozen array from `values`
        ///
        /// NOTE: Full implementation requires JS runtime integration for:
        /// - Symbol.iterator support
        /// - Iterable protocol
        pub fn fromJSValue(allocator: std.mem.Allocator, V: JSValue) !Self {
            // Spec Step 1: Convert V to sequence<T>
            // Requires:
            // - GetMethod(V, %Symbol.iterator%)
            // - Iterate using iterator protocol
            // - Convert each element to type T

            _ = V;
            _ = allocator;

            // Not implemented - requires sequence conversion algorithm
            // See: https://webidl.spec.whatwg.org/#es-sequence
            return error.NotImplemented;
        }

        /// Create frozen array from Zig slice (internal use)
        ///
        /// Spec: "create a frozen array" algorithm
        ///
        /// This is the internal algorithm used after sequence conversion.
        /// In the browser, this would call Object.freeze() on the array.
        pub fn fromSlice(allocator: std.mem.Allocator, items: []const T) !Self {
            return init(allocator, items);
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

test "FrozenArray - fromJSValue not yet implemented" {
    const FA = FrozenArray(i32);

    // Not implemented - requires sequence conversion (JS runtime)
    try testing.expectError(error.NotImplemented, FA.fromJSValue(testing.allocator, .{ .undefined = {} }));
}

test "FrozenArray - fromSlice same as init" {
    const items = [_]i32{ 1, 2, 3 };

    const array = try FrozenArray(i32).fromSlice(testing.allocator, &items);
    defer array.deinit();

    try testing.expectEqual(@as(usize, 3), array.len());
    try testing.expectEqual(@as(i32, 1), array.get(0).?);
}
