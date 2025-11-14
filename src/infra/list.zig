//! WHATWG Infra List Operations
//!
//! Spec: https://infra.spec.whatwg.org/#list
//! WHATWG Infra Standard §5.1 lines 828-908
//!
//! A list is an ordered sequence of items. This implementation uses
//! 4-element inline storage (stack-allocated) before spilling to heap,
//! matching browser implementations (Chromium WTF::Vector, Firefox mozilla::Vector).
//!
//! # Design
//!
//! - **Inline storage**: First 4 elements stored on stack (70-80% hit rate)
//! - **Heap fallback**: Allocates on heap when capacity > 4
//! - **Cache-friendly**: 4 elements fit in single cache line (64 bytes)
//!
//! # Usage
//!
//! ```zig
//! const std = @import("std");
//! const List = @import("list.zig").List;
//!
//! var list = List(u32).init(allocator);
//! defer list.deinit();
//!
//! try list.append(42);
//! try list.prepend(10);
//! const item = list.get(0);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn List(comptime T: type) type {
    return ListWithCapacity(T, 4);
}

pub fn ListWithCapacity(comptime T: type, comptime inline_capacity: usize) type {
    return struct {
        const Self = @This();

        inline_storage: if (inline_capacity > 0) [inline_capacity]T else void = if (inline_capacity > 0) undefined else {},
        heap_storage: ?std.ArrayList(T) = null,
        len: usize = 0,
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.heap_storage) |*heap| {
                heap.deinit(self.allocator);
            }
        }

        pub fn append(self: *Self, item: T) !void {
            // If we've already transitioned to heap, use heap
            if (self.heap_storage != null) {
                try self.heap_storage.?.append(self.allocator, item);
                self.len += 1;
                return;
            }

            // Otherwise try inline storage
            if (comptime inline_capacity > 0) {
                if (self.len < inline_capacity) {
                    self.inline_storage[self.len] = item;
                    self.len += 1;
                    return;
                }
            }

            // Inline storage full, transition to heap
            try self.ensureHeap();
            try self.heap_storage.?.append(self.allocator, item);
            self.len += 1;
        }

        /// Append multiple items at once (batch operation).
        /// More efficient than calling append() in a loop.
        pub fn appendSlice(self: *Self, slice: []const T) !void {
            // If we've already transitioned to heap, use heap
            if (self.heap_storage != null) {
                try self.heap_storage.?.appendSlice(self.allocator, slice);
                self.len += slice.len;
                return;
            }

            // Otherwise try inline storage
            if (comptime inline_capacity > 0) {
                if (self.len + slice.len <= inline_capacity) {
                    // Fast path: all fit in inline storage
                    @memcpy(
                        self.inline_storage[self.len..][0..slice.len],
                        slice,
                    );
                    self.len += slice.len;
                    return;
                } else if (self.len < inline_capacity) {
                    // Mixed: some in inline, rest in heap
                    const inline_space = inline_capacity - self.len;
                    @memcpy(
                        self.inline_storage[self.len..][0..inline_space],
                        slice[0..inline_space],
                    );
                    self.len = inline_capacity;

                    try self.ensureHeap();
                    try self.heap_storage.?.appendSlice(self.allocator, slice[inline_space..]);
                    self.len += slice.len - inline_space;
                    return;
                }
            }
            // Inline storage full, transition to heap
            try self.ensureHeap();
            try self.heap_storage.?.appendSlice(self.allocator, slice);
            self.len += slice.len;
        }

        pub fn prepend(self: *Self, item: T) !void {
            try self.insert(0, item);
        }

        pub fn insert(self: *Self, index: usize, item: T) !void {
            if (index > self.len) {
                return error.IndexOutOfBounds;
            }

            if (comptime inline_capacity > 0) {
                if (self.len < inline_capacity) {
                    var i = self.len;
                    while (i > index) : (i -= 1) {
                        self.inline_storage[i] = self.inline_storage[i - 1];
                    }
                    self.inline_storage[index] = item;
                    self.len += 1;
                    return;
                }
            }
            try self.ensureHeap();
            try self.heap_storage.?.insert(self.allocator, index, item);
            self.len += 1;
        }

        pub fn remove(self: *Self, index: usize) !T {
            if (index >= self.len) {
                return error.IndexOutOfBounds;
            }

            if (self.heap_storage) |*heap| {
                const item = heap.orderedRemove(index);
                self.len -= 1;
                return item;
            }

            if (comptime inline_capacity > 0) {
                const item = self.inline_storage[index];
                var i = index;
                while (i < self.len - 1) : (i += 1) {
                    self.inline_storage[i] = self.inline_storage[i + 1];
                }
                self.len -= 1;
                return item;
            }

            unreachable;
        }

        pub fn replace(self: *Self, index: usize, item: T) !T {
            if (index >= self.len) {
                return error.IndexOutOfBounds;
            }

            if (self.heap_storage) |*heap| {
                const old = heap.items[index];
                heap.items[index] = item;
                return old;
            }

            if (comptime inline_capacity > 0) {
                const old = self.inline_storage[index];
                self.inline_storage[index] = item;
                return old;
            }

            unreachable;
        }

        pub fn get(self: *const Self, index: usize) ?T {
            if (index >= self.len) {
                return null;
            }

            if (self.heap_storage) |heap| {
                return heap.items[index];
            }

            if (comptime inline_capacity > 0) {
                return self.inline_storage[index];
            }

            return null;
        }

        /// Compare two items for equality.
        /// For slices (like []const u8), compares contents instead of pointers.
        /// For other types, uses std.meta.eql.
        inline fn itemsEqual(a: T, b: T) bool {
            // Determine at compile time if T is a slice
            const is_slice = comptime blk: {
                const info = @typeInfo(T);
                break :blk info == .pointer and info.pointer.size == .slice;
            };

            if (is_slice) {
                // For slices, compare contents
                const child = @typeInfo(T).pointer.child;
                return std.mem.eql(child, a, b);
            } else {
                // For other types, use std.meta.eql
                return std.meta.eql(a, b);
            }
        }

        pub fn contains(self: *const Self, item: T) bool {
            if (self.heap_storage) |heap| {
                for (heap.items) |elem| {
                    if (itemsEqual(elem, item)) return true;
                }
                return false;
            }

            if (comptime inline_capacity > 0) {
                for (self.inline_storage[0..self.len]) |elem| {
                    if (itemsEqual(elem, item)) return true;
                }
            }
            return false;
        }

        pub fn size(self: *const Self) usize {
            return self.len;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        /// Get a const slice view of all items in the list.
        /// This is a temporary slice that is valid until the list is modified.
        /// Useful for iteration when you need to access items by index.
        pub fn toSlice(self: *const Self) []const T {
            if (self.heap_storage) |heap| {
                return heap.items;
            } else if (comptime inline_capacity > 0) {
                return self.inline_storage[0..self.len];
            } else {
                return &.{};
            }
        }

        /// Get a mutable slice view of all items in the list.
        /// This is a temporary slice that is valid until the list is modified.
        /// Use this when you need to modify items in place.
        pub fn toSliceMut(self: *Self) []T {
            if (self.heap_storage) |*heap| {
                return heap.items;
            } else if (comptime inline_capacity > 0) {
                return self.inline_storage[0..self.len];
            } else {
                return &.{};
            }
        }

        /// Transfer ownership of all items to the caller as a slice.
        /// The list is cleared and all heap storage is freed.
        /// The caller owns the returned slice and must free it with allocator.free().
        pub fn toOwnedSlice(self: *Self) ![]T {
            if (self.heap_storage) |*heap| {
                const owned = try heap.toOwnedSlice(self.allocator);
                self.len = 0;
                return owned;
            } else if (comptime inline_capacity > 0) {
                if (self.len > 0) {
                    const owned = try self.allocator.dupe(T, self.inline_storage[0..self.len]);
                    self.len = 0;
                    return owned;
                } else {
                    return &.{};
                }
            } else {
                return &.{};
            }
        }

        /// Clear all items from the list.
        /// WHATWG Infra Standard §5.1 line 882: "To **empty** a list is to remove all of its items."
        pub fn clear(self: *Self) void {
            if (self.heap_storage) |*heap| {
                heap.clearRetainingCapacity();
            }
            self.len = 0;
        }

        /// Alias for clear(). Remove all items from the list.
        /// WHATWG Infra Standard §5.1 line 882: "To **empty** a list is to remove all of its items."
        pub const empty = clear;

        pub fn clone(self: *const Self) !Self {
            var new_list = Self.init(self.allocator);

            if (self.heap_storage) |heap| {
                for (heap.items) |item| {
                    try new_list.append(item);
                }
            } else if (comptime inline_capacity > 0) {
                for (self.inline_storage[0..self.len]) |item| {
                    try new_list.append(item);
                }
            }

            return new_list;
        }

        pub fn extend(self: *Self, other: *const Self) !void {
            if (other.heap_storage) |heap| {
                for (heap.items) |item| {
                    try self.append(item);
                }
            } else if (comptime inline_capacity > 0) {
                for (other.inline_storage[0..other.len]) |item| {
                    try self.append(item);
                }
            }
        }

        pub fn sort(self: *Self, comptime lessThan: fn (T, T) bool) void {
            if (self.heap_storage) |*heap| {
                std.mem.sort(T, heap.items, {}, struct {
                    fn inner(_: void, a: T, b: T) bool {
                        return lessThan(a, b);
                    }
                }.inner);
            } else if (comptime inline_capacity > 0) {
                std.mem.sort(T, self.inline_storage[0..self.len], {}, struct {
                    fn inner(_: void, a: T, b: T) bool {
                        return lessThan(a, b);
                    }
                }.inner);
            }
        }

        pub fn sortDescending(self: *Self, comptime lessThan: fn (T, T) bool) void {
            if (self.heap_storage) |*heap| {
                std.mem.sort(T, heap.items, {}, struct {
                    fn inner(_: void, a: T, b: T) bool {
                        return lessThan(b, a);
                    }
                }.inner);
            } else if (comptime inline_capacity > 0) {
                std.mem.sort(T, self.inline_storage[0..self.len], {}, struct {
                    fn inner(_: void, a: T, b: T) bool {
                        return lessThan(b, a);
                    }
                }.inner);
            }
        }

        pub fn getIndices(self: *const Self, allocator: Allocator) ![]const usize {
            const indices = try allocator.alloc(usize, self.len);
            for (0..self.len) |i| {
                indices[i] = i;
            }
            return indices;
        }

        /// Replace all items matching a condition with a given item.
        /// WHATWG Infra Standard §5.1 line 870: "To **replace** within a list that is not
        /// an ordered set is to replace all items from the list that match a given condition
        /// with the given item, or do nothing if none do."
        pub fn replaceMatching(self: *Self, condition: fn (T) bool, item: T) void {
            if (self.heap_storage) |*heap| {
                for (heap.items, 0..) |elem, i| {
                    if (condition(elem)) {
                        heap.items[i] = item;
                    }
                }
            } else if (comptime inline_capacity > 0) {
                for (self.inline_storage[0..self.len], 0..) |elem, i| {
                    if (condition(elem)) {
                        self.inline_storage[i] = item;
                    }
                }
            }
        }

        /// Remove all items matching a condition from the list.
        /// WHATWG Infra Standard §5.1 line 876: "To **remove** zero or more items from
        /// a list is to remove all items from the list that match a given condition,
        /// or do nothing if none do."
        pub fn removeMatching(self: *Self, condition: fn (T) bool) void {
            var i: usize = 0;
            while (i < self.len) {
                const elem = if (self.heap_storage) |heap|
                    heap.items[i]
                else if (comptime inline_capacity > 0)
                    self.inline_storage[i]
                else
                    unreachable;

                if (condition(elem)) {
                    _ = self.remove(i) catch unreachable;
                } else {
                    i += 1;
                }
            }
        }

        pub fn items(self: *const Self) []const T {
            if (self.heap_storage) |heap| {
                return heap.items;
            }

            if (comptime inline_capacity > 0) {
                return self.inline_storage[0..self.len];
            }

            return &[_]T{};
        }

        /// Get a mutable slice of items for sorting or other operations
        /// Returns a slice that can be passed to std.mem.sort
        /// Useful when you need to sort with custom context
        pub fn sortableSlice(self: *Self) []T {
            if (self.heap_storage) |*heap| {
                return heap.items;
            }

            if (comptime inline_capacity > 0) {
                return self.inline_storage[0..self.len];
            }

            return &[_]T{};
        }

        pub fn ensureCapacity(self: *Self, capacity: usize) !void {
            if (capacity <= inline_capacity) {
                return;
            }

            try self.ensureHeap();

            if (self.heap_storage) |*heap| {
                if (heap.capacity < capacity) {
                    try heap.ensureTotalCapacity(self.allocator, capacity);
                }
            }
        }

        fn ensureHeap(self: *Self) !void {
            if (self.heap_storage == null) {
                const initial_capacity = if (inline_capacity > 0) inline_capacity * 2 else 4;
                var heap = try std.ArrayList(T).initCapacity(self.allocator, initial_capacity);

                if (comptime inline_capacity > 0) {
                    for (self.inline_storage[0..self.len]) |item| {
                        try heap.append(self.allocator, item);
                    }
                }

                self.heap_storage = heap;
            }
        }
    };
}

























// ============================================================================
// Configurable Inline Capacity Tests
// ============================================================================







