//! WHATWG Infra Ordered Map Operations
//!
//! Spec: https://infra.spec.whatwg.org/#ordered-map
//! WHATWG Infra Standard §5.2 lines 980-1033
//!
//! An ordered map is an ordered list of tuples (key-value pairs). It preserves
//! insertion order, which is required by the spec. This implementation uses a
//! list-backed approach with linear search, matching browser implementations.
//!
//! # Design
//!
//! - **List-backed**: Uses `List` with 4-entry inline storage
//! - **Linear search**: O(n) but faster than HashMap for small n (< 12)
//! - **Insertion order**: Naturally preserved (it's a list)
//! - **Cache-friendly**: Sequential memory access
//!
//! # Performance
//!
//! Browser research (Chromium, Firefox) shows:
//! - Linear search is faster than HashMap for n < 12 (cache locality)
//! - 70-80% of maps have ≤ 4 entries
//! - Typical use case: DOM attributes, HTTP headers, JSON objects
//!
//! # Usage
//!
//! ```zig
//! const std = @import("std");
//! const OrderedMap = @import("map.zig").OrderedMap;
//!
//! var map = OrderedMap([]const u8, u32).init(allocator);
//! defer map.deinit();
//!
//! try map.set("key", 100);
//! const value = map.get("key");  // returns ?u32
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const List = @import("list.zig").List;
const OrderedSetType = @import("set.zig").OrderedSet;

pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Entry = struct {
            key: K,
            value: V,
        };

        entries: List(Entry),

        /// Comptime-optimized key equality check.
        /// For integers and simple types, use direct ==.
        /// For complex types, fall back to std.meta.eql.
        inline fn keyEql(a: K, b: K) bool {
            const type_info = @typeInfo(K);
            return switch (type_info) {
                .int, .float, .bool, .@"enum" => a == b,
                else => std.meta.eql(a, b),
            };
        }

        pub fn init(allocator: Allocator) Self {
            return Self{
                .entries = List(Entry).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.entries.deinit();
        }

        pub fn get(self: *const Self, key: K) ?V {
            const items_slice = self.entries.items();
            for (items_slice) |entry| {
                if (keyEql(entry.key, key)) {
                    return entry.value;
                }
            }
            return null;
        }

        /// Get the value of an entry with a default value if key doesn't exist.
        /// WHATWG Infra Standard §5.2 lines 992-999
        ///
        /// To **get the value of an entry** in an ordered map `map` given a key `key`
        /// and an optional `default`:
        /// 1. If `map` does not contain `key` and `default` is given, then return `default`.
        /// 2. Assert: `map` contains `key`.
        /// 3. Return the value of the entry in `map` whose key is `key`.
        ///
        /// This implements the "with default" phrase from the spec, allowing:
        /// `map.getWithDefault(key, default_value)`
        pub fn getWithDefault(self: *const Self, key: K, default: V) V {
            return self.get(key) orelse default;
        }

        pub fn set(self: *Self, key: K, value: V) !void {
            const items_slice = self.entries.items();
            for (items_slice, 0..) |entry, i| {
                if (keyEql(entry.key, key)) {
                    _ = try self.entries.replace(i, Entry{ .key = key, .value = value });
                    return;
                }
            }
            try self.entries.append(Entry{ .key = key, .value = value });
        }

        pub fn remove(self: *Self, key: K) bool {
            const items_slice = self.entries.items();
            for (items_slice, 0..) |entry, i| {
                if (keyEql(entry.key, key)) {
                    _ = self.entries.remove(i) catch unreachable;
                    return true;
                }
            }
            return false;
        }

        pub fn contains(self: *const Self, key: K) bool {
            return self.get(key) != null;
        }

        pub fn size(self: *const Self) usize {
            return self.entries.size();
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.entries.isEmpty();
        }

        pub fn clear(self: *Self) void {
            self.entries.clear();
        }

        pub fn clone(self: *const Self) !Self {
            var new_map = Self.init(self.entries.allocator);
            const items_slice = self.entries.items();
            for (items_slice) |entry| {
                try new_map.entries.append(entry);
            }
            return new_map;
        }

        pub const Iterator = struct {
            items_slice: []const Entry,
            index: usize = 0,

            pub fn next(it: *Iterator) ?Entry {
                if (it.index >= it.items_slice.len) return null;
                const entry = it.items_slice[it.index];
                it.index += 1;
                return entry;
            }
        };

        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .items_slice = self.entries.items(),
            };
        }

        pub fn getKeys(self: *const Self) !OrderedSetType(K) {
            var keys = OrderedSetType(K).init(self.entries.allocator);
            const items_slice = self.entries.items();
            for (items_slice) |entry| {
                _ = try keys.add(entry.key);
            }
            return keys;
        }

        pub fn getValues(self: *const Self) !List(V) {
            var values = List(V).init(self.entries.allocator);
            const items_slice = self.entries.items();
            for (items_slice) |entry| {
                try values.append(entry.value);
            }
            return values;
        }

        pub fn sortAscending(self: *const Self, lessThan: fn (Entry, Entry) bool) !Self {
            var sorted = try self.clone();
            sorted.entries.sort(lessThan);
            return sorted;
        }

        pub fn sortDescending(self: *const Self, lessThan: fn (Entry, Entry) bool) !Self {
            var sorted = try self.clone();
            sorted.entries.sort(struct {
                fn inner(a: Entry, b: Entry) bool {
                    return lessThan(b, a);
                }
            }.inner);
            return sorted;
        }
    };
}






















