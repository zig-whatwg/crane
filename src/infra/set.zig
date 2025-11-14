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

































