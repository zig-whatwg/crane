//! WHATWG Infra Ordered Set Operations
//!
//! Spec: https://infra.spec.whatwg.org/#ordered-set
//! WHATWG Infra Standard §5.1.3 lines 936-978
//!
//! An ordered set is a list that contains no duplicates and preserves
//! insertion order.

const std = @import("std");
const Allocator = std.mem.Allocator;
const List = @import("list.zig").List;
const String = @import("string.zig").String;

pub fn OrderedSet(comptime T: type) type {
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

        pub fn add(self: *Self, item: T) !bool {
            if (self.contains(item)) {
                return false;
            }
            try self.items_list.append(item);
            return true;
        }

        /// Append to ordered set (spec-compliant naming).
        /// If the set contains the given item, then do nothing; otherwise,
        /// perform the normal list append operation.
        /// WHATWG Infra Standard §5.1.3 line 949
        pub fn append(self: *Self, item: T) !void {
            _ = try self.add(item);
        }

        pub fn remove(self: *Self, item: T) bool {
            const items_slice = self.items_list.items();
            for (items_slice, 0..) |elem, i| {
                if (std.meta.eql(elem, item)) {
                    _ = self.items_list.remove(i) catch unreachable;
                    return true;
                }
            }
            return false;
        }

        pub fn contains(self: *const Self, item: T) bool {
            return self.items_list.contains(item);
        }

        pub fn size(self: *const Self) usize {
            return self.items_list.size();
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.items_list.isEmpty();
        }

        pub fn clear(self: *Self) void {
            self.items_list.clear();
        }

        pub fn clone(self: *const Self) !Self {
            var new_set = Self.init(self.items_list.allocator);
            const items_slice = self.items_list.items();
            for (items_slice) |item| {
                try new_set.items_list.append(item);
            }
            return new_set;
        }

        pub const Iterator = struct {
            items_slice: []const T,
            index: usize = 0,

            pub fn next(it: *Iterator) ?T {
                if (it.index >= it.items_slice.len) return null;
                const item = it.items_slice[it.index];
                it.index += 1;
                return item;
            }
        };

        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .items_slice = self.items_list.items(),
            };
        }

        pub fn extend(self: *Self, other: *const Self) !void {
            const items_slice = other.items_list.items();
            for (items_slice) |item| {
                _ = try self.add(item);
            }
        }

        pub fn prepend(self: *Self, item: T) !void {
            if (self.contains(item)) {
                return;
            }
            try self.items_list.insert(0, item);
        }

        pub fn replace(self: *Self, item: T, replacement: T) !void {
            const items_slice = self.items_list.items();
            var found_item: ?usize = null;
            var found_replacement: ?usize = null;

            for (items_slice, 0..) |elem, i| {
                if (std.meta.eql(elem, item)) {
                    found_item = i;
                }
                if (std.meta.eql(elem, replacement)) {
                    found_replacement = i;
                }
            }

            if (found_item) |item_idx| {
                if (found_replacement) |repl_idx| {
                    const first_idx = @min(item_idx, repl_idx);
                    _ = try self.items_list.replace(first_idx, replacement);
                    const second_idx = @max(item_idx, repl_idx);
                    _ = try self.items_list.remove(second_idx);
                } else {
                    _ = try self.items_list.replace(item_idx, replacement);
                }
            } else if (found_replacement) |repl_idx| {
                _ = try self.items_list.replace(repl_idx, replacement);
            }
        }

        pub fn isSubset(self: *const Self, superset: *const Self) bool {
            const items_slice = self.items_list.items();
            for (items_slice) |item| {
                if (!superset.contains(item)) {
                    return false;
                }
            }
            return true;
        }

        pub fn isSuperset(self: *const Self, subset: *const Self) bool {
            return subset.isSubset(self);
        }

        pub fn equals(self: *const Self, other: *const Self) bool {
            return self.isSubset(other) and self.isSuperset(other);
        }

        pub fn intersection(self: *const Self, other: *const Self) !Self {
            var result = Self.init(self.items_list.allocator);
            const items_slice = self.items_list.items();
            for (items_slice) |item| {
                if (other.contains(item)) {
                    try result.items_list.append(item);
                }
            }
            return result;
        }

        pub fn unionWith(self: *const Self, other: *const Self) !Self {
            var result = try self.clone();
            try result.extend(other);
            return result;
        }

        pub fn difference(self: *const Self, other: *const Self) !Self {
            var result = Self.init(self.items_list.allocator);
            const items_slice = self.items_list.items();
            for (items_slice) |item| {
                if (!other.contains(item)) {
                    try result.items_list.append(item);
                }
            }
            return result;
        }
    };
}

/// Serialize a set of strings by concatenating items with U+0020 SPACE separator.
/// WHATWG Infra Standard §4.6 line 813
pub fn serializeStringSet(allocator: Allocator, set: *const OrderedSet(String)) !String {
    const string_module = @import("string.zig");
    const items_slice = set.items_list.items();
    const separator = [_]u16{0x0020};
    return string_module.concatenate(allocator, items_slice, &separator);
}

/// Create an ordered set containing all integers from n to m, inclusive.
/// WHATWG Infra Standard §5.1.3 lines 972-975
///
/// The range n to m, inclusive, creates a new ordered set containing all of
/// the integers from n up to and including m in consecutively increasing order,
/// as long as m is greater than or equal to n.
///
/// If m < n, returns an empty set.
pub fn rangeInclusive(allocator: Allocator, comptime T: type, n: T, m: T) !OrderedSet(T) {
    var result = OrderedSet(T).init(allocator);
    errdefer result.deinit();

    if (m < n) {
        return result;
    }

    var i = n;
    while (i <= m) : (i += 1) {
        try result.append(i);
    }

    return result;
}

/// Create an ordered set containing all integers from n to m-1.
/// WHATWG Infra Standard §5.1.3 lines 975-978
///
/// The range n to m, exclusive, creates a new ordered set containing all of
/// the integers from n up to and including m − 1 in consecutively increasing order,
/// as long as m is greater than n. If m equals n, then it creates an empty ordered set.
///
/// If m <= n, returns an empty set.
pub fn rangeExclusive(allocator: Allocator, comptime T: type, n: T, m: T) !OrderedSet(T) {
    var result = OrderedSet(T).init(allocator);
    errdefer result.deinit();

    if (m <= n) {
        return result;
    }

    var i = n;
    while (i < m) : (i += 1) {
        try result.append(i);
    }

    return result;
}

test "OrderedSet - init and deinit" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.size());
    try std.testing.expect(set.isEmpty());
}

test "OrderedSet - add unique items" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    const added1 = try set.add(1);
    const added2 = try set.add(2);

    try std.testing.expect(added1);
    try std.testing.expect(added2);
    try std.testing.expectEqual(@as(usize, 2), set.size());
}

test "OrderedSet - add duplicate (no-op)" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    const added = try set.add(1);

    try std.testing.expect(!added);
    try std.testing.expectEqual(@as(usize, 1), set.size());
}

test "OrderedSet - remove existing item" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);

    const removed = set.remove(1);
    try std.testing.expect(removed);
    try std.testing.expect(!set.contains(1));
    try std.testing.expectEqual(@as(usize, 1), set.size());
}

test "OrderedSet - remove nonexistent item (no-op)" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    const removed = set.remove(999);
    try std.testing.expect(!removed);
}

test "OrderedSet - contains" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);

    try std.testing.expect(set.contains(1));
    try std.testing.expect(!set.contains(999));
}

test "OrderedSet - preserves insertion order" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(3);
    _ = try set.add(1);
    _ = try set.add(2);

    var it = set.iterator();
    try std.testing.expectEqual(@as(?u32, 3), it.next());
    try std.testing.expectEqual(@as(?u32, 1), it.next());
    try std.testing.expectEqual(@as(?u32, 2), it.next());
    try std.testing.expectEqual(@as(?u32, null), it.next());
}

test "OrderedSet - clear" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);
    set.clear();

    try std.testing.expect(set.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), set.size());
}

test "OrderedSet - clone" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);

    var cloned = try set.clone();
    defer cloned.deinit();

    try std.testing.expectEqual(set.size(), cloned.size());
    try std.testing.expect(cloned.contains(1));
    try std.testing.expect(cloned.contains(2));
}

test "OrderedSet - no memory leaks" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        _ = try set.add(i);
    }

    try std.testing.expectEqual(@as(usize, 10), set.size());
}

test "OrderedSet - extend" {
    const allocator = std.testing.allocator;
    var set1 = OrderedSet(u32).init(allocator);
    defer set1.deinit();
    var set2 = OrderedSet(u32).init(allocator);
    defer set2.deinit();

    _ = try set1.add(1);
    _ = try set1.add(2);
    _ = try set2.add(3);
    _ = try set2.add(4);

    try set1.extend(&set2);

    try std.testing.expectEqual(@as(usize, 4), set1.size());
    try std.testing.expect(set1.contains(1));
    try std.testing.expect(set1.contains(2));
    try std.testing.expect(set1.contains(3));
    try std.testing.expect(set1.contains(4));
}

test "OrderedSet - extend with duplicates" {
    const allocator = std.testing.allocator;
    var set1 = OrderedSet(u32).init(allocator);
    defer set1.deinit();
    var set2 = OrderedSet(u32).init(allocator);
    defer set2.deinit();

    _ = try set1.add(1);
    _ = try set1.add(2);
    _ = try set2.add(2);
    _ = try set2.add(3);

    try set1.extend(&set2);

    try std.testing.expectEqual(@as(usize, 3), set1.size());
}

test "OrderedSet - prepend" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(2);
    _ = try set.add(3);
    try set.prepend(1);

    var it = set.iterator();
    try std.testing.expectEqual(@as(?u32, 1), it.next());
    try std.testing.expectEqual(@as(?u32, 2), it.next());
    try std.testing.expectEqual(@as(?u32, 3), it.next());
}

test "OrderedSet - prepend duplicate" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);
    try set.prepend(1);

    try std.testing.expectEqual(@as(usize, 2), set.size());
}

test "OrderedSet - replace" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);
    _ = try set.add(3);

    try set.replace(2, 5);

    try std.testing.expectEqual(@as(usize, 3), set.size());
    try std.testing.expect(!set.contains(2));
    try std.testing.expect(set.contains(5));
}

test "OrderedSet - replace with existing" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);
    _ = try set.add(3);

    try set.replace(2, 3);

    try std.testing.expectEqual(@as(usize, 2), set.size());
    try std.testing.expect(!set.contains(2));
    try std.testing.expect(set.contains(3));
}

test "OrderedSet - isSubset" {
    const allocator = std.testing.allocator;
    var set1 = OrderedSet(u32).init(allocator);
    defer set1.deinit();
    var set2 = OrderedSet(u32).init(allocator);
    defer set2.deinit();

    _ = try set1.add(1);
    _ = try set1.add(2);
    _ = try set2.add(1);
    _ = try set2.add(2);
    _ = try set2.add(3);

    try std.testing.expect(set1.isSubset(&set2));
    try std.testing.expect(!set2.isSubset(&set1));
}

test "OrderedSet - isSuperset" {
    const allocator = std.testing.allocator;
    var set1 = OrderedSet(u32).init(allocator);
    defer set1.deinit();
    var set2 = OrderedSet(u32).init(allocator);
    defer set2.deinit();

    _ = try set1.add(1);
    _ = try set1.add(2);
    _ = try set1.add(3);
    _ = try set2.add(1);
    _ = try set2.add(2);

    try std.testing.expect(set1.isSuperset(&set2));
    try std.testing.expect(!set2.isSuperset(&set1));
}

test "OrderedSet - equals" {
    const allocator = std.testing.allocator;
    var set1 = OrderedSet(u32).init(allocator);
    defer set1.deinit();
    var set2 = OrderedSet(u32).init(allocator);
    defer set2.deinit();

    _ = try set1.add(1);
    _ = try set1.add(2);
    _ = try set2.add(1);
    _ = try set2.add(2);

    try std.testing.expect(set1.equals(&set2));
}

test "OrderedSet - intersection" {
    const allocator = std.testing.allocator;
    var set1 = OrderedSet(u32).init(allocator);
    defer set1.deinit();
    var set2 = OrderedSet(u32).init(allocator);
    defer set2.deinit();

    _ = try set1.add(1);
    _ = try set1.add(2);
    _ = try set1.add(3);
    _ = try set2.add(2);
    _ = try set2.add(3);
    _ = try set2.add(4);

    var result = try set1.intersection(&set2);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.size());
    try std.testing.expect(result.contains(2));
    try std.testing.expect(result.contains(3));
}

test "OrderedSet - union" {
    const allocator = std.testing.allocator;
    var set1 = OrderedSet(u32).init(allocator);
    defer set1.deinit();
    var set2 = OrderedSet(u32).init(allocator);
    defer set2.deinit();

    _ = try set1.add(1);
    _ = try set1.add(2);
    _ = try set2.add(3);
    _ = try set2.add(4);

    var result = try set1.unionWith(&set2);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 4), result.size());
    try std.testing.expect(result.contains(1));
    try std.testing.expect(result.contains(2));
    try std.testing.expect(result.contains(3));
    try std.testing.expect(result.contains(4));
}

test "OrderedSet - difference" {
    const allocator = std.testing.allocator;
    var set1 = OrderedSet(u32).init(allocator);
    defer set1.deinit();
    var set2 = OrderedSet(u32).init(allocator);
    defer set2.deinit();

    _ = try set1.add(1);
    _ = try set1.add(2);
    _ = try set1.add(3);
    _ = try set2.add(2);
    _ = try set2.add(3);

    var result = try set1.difference(&set2);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.size());
    try std.testing.expect(result.contains(1));
}

test "OrderedSet - append alias" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    try set.append(1);
    try set.append(2);
    try set.append(1);

    try std.testing.expectEqual(@as(usize, 2), set.size());
    try std.testing.expect(set.contains(1));
    try std.testing.expect(set.contains(2));
}

test "serializeStringSet - empty set" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(String).init(allocator);
    defer set.deinit();

    const result = try serializeStringSet(allocator, &set);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "serializeStringSet - single item" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(String).init(allocator);
    defer set.deinit();

    const str1 = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    _ = try set.add(&str1);

    const result = try serializeStringSet(allocator, &set);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "serializeStringSet - multiple items with space" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(String).init(allocator);
    defer set.deinit();

    const string_module = @import("string.zig");
    const str1 = try string_module.utf8ToUtf16(allocator, "hello");
    defer allocator.free(str1);
    const str2 = try string_module.utf8ToUtf16(allocator, "world");
    defer allocator.free(str2);
    const str3 = try string_module.utf8ToUtf16(allocator, "test");
    defer allocator.free(str3);

    _ = try set.add(str1);
    _ = try set.add(str2);
    _ = try set.add(str3);

    const result = try serializeStringSet(allocator, &set);
    defer allocator.free(result);

    const result_utf8 = try string_module.utf16ToUtf8(allocator, result);
    defer allocator.free(result_utf8);

    try std.testing.expectEqualStrings("hello world test", result_utf8);
}

test "rangeInclusive - basic range" {
    const allocator = std.testing.allocator;
    var set = try rangeInclusive(allocator, u32, 1, 4);
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 4), set.size());
    try std.testing.expect(set.contains(1));
    try std.testing.expect(set.contains(2));
    try std.testing.expect(set.contains(3));
    try std.testing.expect(set.contains(4));
}

test "rangeInclusive - single element" {
    const allocator = std.testing.allocator;
    var set = try rangeInclusive(allocator, u32, 5, 5);
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 1), set.size());
    try std.testing.expect(set.contains(5));
}

test "rangeInclusive - empty when m < n" {
    const allocator = std.testing.allocator;
    var set = try rangeInclusive(allocator, u32, 10, 5);
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.size());
    try std.testing.expect(set.isEmpty());
}

test "rangeExclusive - basic range" {
    const allocator = std.testing.allocator;
    var set = try rangeExclusive(allocator, u32, 0, 4);
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 4), set.size());
    try std.testing.expect(set.contains(0));
    try std.testing.expect(set.contains(1));
    try std.testing.expect(set.contains(2));
    try std.testing.expect(set.contains(3));
    try std.testing.expect(!set.contains(4));
}

test "rangeExclusive - empty when m == n" {
    const allocator = std.testing.allocator;
    var set = try rangeExclusive(allocator, u32, 5, 5);
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.size());
    try std.testing.expect(set.isEmpty());
}

test "rangeExclusive - empty when m < n" {
    const allocator = std.testing.allocator;
    var set = try rangeExclusive(allocator, u32, 10, 5);
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.size());
    try std.testing.expect(set.isEmpty());
}

test "rangeInclusive - preserves order" {
    const allocator = std.testing.allocator;
    var set = try rangeInclusive(allocator, u32, 1, 5);
    defer set.deinit();

    var it = set.iterator();
    try std.testing.expectEqual(@as(?u32, 1), it.next());
    try std.testing.expectEqual(@as(?u32, 2), it.next());
    try std.testing.expectEqual(@as(?u32, 3), it.next());
    try std.testing.expectEqual(@as(?u32, 4), it.next());
    try std.testing.expectEqual(@as(?u32, 5), it.next());
    try std.testing.expectEqual(@as(?u32, null), it.next());
}
