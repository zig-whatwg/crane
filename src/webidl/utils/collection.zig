//! CollectionMixin - Generic collection pattern utilities for indexed access
//!
//! This utility provides implementations for the common collection patterns
//! found in DOM interfaces: get_length, call_item, and call_namedItem.
//! These patterns appear in 56+ impl files.
//!
//! ## Migration Status
//!
//! After analysis of existing impl files, mass migration was determined to have
//! limited value because:
//!
//! 1. Only ~6 files have actual implementations (most are stubs returning NotImplemented)
//! 2. Each implementation uses different field names (nodes, elements, tokens, etc.)
//! 3. Different element types (*runtime.Instance, DOMString, []const u8)
//! 4. Some have special logic (live collections, custom bounds handling)
//! 5. Code savings are minimal (1-3 lines per function)
//!
//! This utility is best used for **new collection implementations** to ensure
//! consistent patterns. Existing implementations can optionally adopt it during
//! normal maintenance work.
//!
//! ## Usage
//!
//! For a simple collection with just length and item:
//! ```zig
//! const CollectionHelpers = CollectionMixin(*runtime.Instance);
//!
//! pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
//!     const internal = getInternal(instance) orelse return 0;
//!     return CollectionHelpers.getLength(internal.elements);
//! }
//!
//! pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
//!     const internal = getInternal(instance) orelse return null;
//!     return CollectionHelpers.getItem(internal.elements, index);
//! }
//! ```
//!
//! ## Supported Collection Types
//!
//! The helpers work with any collection that has:
//! - `.items` field (ArrayList-like) or `.len` and indexing
//! - `.size()` method (infra.List)
//! - Array/slice types
//!
//! ## Benefits
//!
//! - Consistent null-safe access patterns
//! - Proper bounds checking
//! - Works with multiple collection types
//! - ~4 lines saved per get_length/call_item implementation

const std = @import("std");

/// Generic helpers for collection-style access patterns.
///
/// @param ElementT - The element type stored in collections (e.g., *runtime.Instance)
pub fn CollectionMixin(comptime ElementT: type) type {
    return struct {
        /// Get the length of a collection.
        /// Works with ArrayList, infra.List, slices, and arrays.
        pub fn getLength(collection: anytype) u32 {
            const T = @TypeOf(collection);
            const info = @typeInfo(T);

            // Handle optional types
            if (info == .optional) {
                if (collection) |c| {
                    return getLengthImpl(c);
                }
                return 0;
            }

            return getLengthImpl(collection);
        }

        fn getLengthImpl(collection: anytype) u32 {
            const T = @TypeOf(collection);
            const info = @typeInfo(T);

            // Handle pointers (e.g., *ArrayList, *infra.List)
            if (info == .pointer and info.pointer.size == .one) {
                const ChildT = info.pointer.child;
                const child_info = @typeInfo(ChildT);

                // Dereference and recurse for structs
                if (child_info == .@"struct") {
                    return getLengthImpl(collection.*);
                }
            }

            // Slice (check before @hasField/@hasDecl since slices don't have those)
            if (info == .pointer and info.pointer.size == .slice) {
                return @intCast(collection.len);
            }

            // Array
            if (info == .array) {
                return @intCast(info.array.len);
            }

            // For struct types only, check for specific fields/methods
            if (info == .@"struct") {
                // ArrayList-like (has .items field)
                if (@hasField(T, "items")) {
                    return @intCast(collection.items.len);
                }

                // infra.List-like (has .size() method)
                if (@hasDecl(T, "size")) {
                    return @intCast(collection.size());
                }

                // Has .len field directly
                if (@hasField(T, "len")) {
                    return @intCast(collection.len);
                }
            }

            @compileError("Collection type must have .items, .size(), .len, or be a slice/array");
        }

        /// Get an item at the given index, with bounds checking.
        /// Returns null if index is out of bounds or collection is null.
        pub fn getItem(collection: anytype, index: u32) ?ElementT {
            const T = @TypeOf(collection);
            const info = @typeInfo(T);

            // Handle optional types
            if (info == .optional) {
                if (collection) |c| {
                    return getItemImpl(c, index);
                }
                return null;
            }

            return getItemImpl(collection, index);
        }

        fn getItemImpl(collection: anytype, index: u32) ?ElementT {
            const T = @TypeOf(collection);
            const info = @typeInfo(T);

            // Handle pointers (e.g., *ArrayList, *infra.List)
            if (info == .pointer and info.pointer.size == .one) {
                const ChildT = info.pointer.child;
                const child_info = @typeInfo(ChildT);

                if (child_info == .@"struct") {
                    return getItemImpl(collection.*, index);
                }
            }

            // Slice (check before @hasField/@hasDecl since slices don't have those)
            if (info == .pointer and info.pointer.size == .slice) {
                if (index >= collection.len) return null;
                return collection[index];
            }

            // Array
            if (info == .array) {
                if (index >= info.array.len) return null;
                return collection[index];
            }

            // For struct types only, check for specific fields/methods
            if (info == .@"struct") {
                // ArrayList-like (has .items field)
                if (@hasField(T, "items")) {
                    if (index >= collection.items.len) return null;
                    return collection.items[index];
                }

                // infra.List-like (has .get() method)
                if (@hasDecl(T, "get")) {
                    const result = collection.get(index);
                    // Handle error union from get()
                    if (@typeInfo(@TypeOf(result)) == .error_union) {
                        return result catch null;
                    }
                    return result;
                }
            }

            @compileError("Collection type must have .items, .get(), or be a slice/array");
        }

        /// Get item as a slice at given index (for collections of strings).
        /// Returns null if index is out of bounds.
        pub fn getItemSlice(collection: anytype, index: u32) ?[]const u8 {
            const T = @TypeOf(collection);
            const info = @typeInfo(T);

            // Handle optional
            if (info == .optional) {
                if (collection) |c| {
                    return getItemSliceImpl(c, index);
                }
                return null;
            }

            return getItemSliceImpl(collection, index);
        }

        fn getItemSliceImpl(collection: anytype, index: u32) ?[]const u8 {
            const T = @TypeOf(collection);

            // ArrayList of strings
            if (@hasField(T, "items")) {
                if (index >= collection.items.len) return null;
                const item = collection.items[index];
                // Handle DOMString-like types
                const ItemType = @TypeOf(item);
                if (@typeInfo(ItemType) == .@"struct" and @hasDecl(ItemType, "asSlice")) {
                    return item.asSlice();
                }
                // Direct slice
                return item;
            }

            // infra.List of strings
            if (@hasDecl(T, "get")) {
                const result = collection.get(index) catch return null;
                const ResultType = @TypeOf(result);
                if (@typeInfo(ResultType) == .@"struct" and @hasDecl(ResultType, "asSlice")) {
                    return result.asSlice();
                }
                return result;
            }

            return null;
        }

        /// Check if collection contains a value.
        /// Uses equality comparison based on element type.
        pub fn contains(collection: anytype, value: ElementT) bool {
            const T = @TypeOf(collection);
            const info = @typeInfo(T);

            // Handle optional
            if (info == .optional) {
                if (collection) |c| {
                    return containsImpl(c, value);
                }
                return false;
            }

            return containsImpl(collection, value);
        }

        fn containsImpl(collection: anytype, value: ElementT) bool {
            const T = @TypeOf(collection);

            // ArrayList-like
            if (@hasField(T, "items")) {
                for (collection.items) |item| {
                    if (item == value) return true;
                }
                return false;
            }

            // infra.List-like (has toSlice)
            if (@hasDecl(T, "toSlice")) {
                for (collection.toSlice()) |item| {
                    if (item == value) return true;
                }
                return false;
            }

            return false;
        }
    };
}

/// Specialized helpers for string collections (DOMStringList-like).
pub const StringCollectionMixin = struct {
    /// Check if a string is in the collection.
    pub fn containsString(collection: anytype, value: []const u8) bool {
        const T = @TypeOf(collection);

        // Handle optional
        if (@typeInfo(T) == .optional) {
            if (collection) |c| {
                return containsStringImpl(c, value);
            }
            return false;
        }

        return containsStringImpl(collection, value);
    }

    fn containsStringImpl(collection: anytype, value: []const u8) bool {
        const T = @TypeOf(collection);

        // ArrayList-like
        if (@hasField(T, "items")) {
            for (collection.items) |item| {
                const ItemType = @TypeOf(item);
                const slice = if (@typeInfo(ItemType) == .@"struct" and @hasDecl(ItemType, "asSlice"))
                    item.asSlice()
                else
                    item;
                if (std.mem.eql(u8, slice, value)) return true;
            }
            return false;
        }

        // infra.List-like
        if (@hasDecl(T, "toSlice")) {
            for (collection.toSlice()) |item| {
                const ItemType = @TypeOf(item);
                const slice = if (@typeInfo(ItemType) == .@"struct" and @hasDecl(ItemType, "asSlice"))
                    item.asSlice()
                else
                    item;
                if (std.mem.eql(u8, slice, value)) return true;
            }
            return false;
        }

        return false;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "CollectionMixin - getLength with ArrayList" {
    var list = std.ArrayListUnmanaged(u32){};
    defer list.deinit(std.testing.allocator);

    try list.append(std.testing.allocator, 1);
    try list.append(std.testing.allocator, 2);
    try list.append(std.testing.allocator, 3);

    const Helpers = CollectionMixin(u32);
    try std.testing.expectEqual(@as(u32, 3), Helpers.getLength(list));
}

test "CollectionMixin - getLength with slice" {
    const slice: []const u32 = &[_]u32{ 1, 2, 3, 4, 5 };
    const Helpers = CollectionMixin(u32);
    try std.testing.expectEqual(@as(u32, 5), Helpers.getLength(slice));
}

test "CollectionMixin - getItem with ArrayList" {
    var list = std.ArrayListUnmanaged(u32){};
    defer list.deinit(std.testing.allocator);

    try list.append(std.testing.allocator, 10);
    try list.append(std.testing.allocator, 20);
    try list.append(std.testing.allocator, 30);

    const Helpers = CollectionMixin(u32);
    try std.testing.expectEqual(@as(?u32, 10), Helpers.getItem(list, 0));
    try std.testing.expectEqual(@as(?u32, 20), Helpers.getItem(list, 1));
    try std.testing.expectEqual(@as(?u32, 30), Helpers.getItem(list, 2));
    try std.testing.expectEqual(@as(?u32, null), Helpers.getItem(list, 3));
    try std.testing.expectEqual(@as(?u32, null), Helpers.getItem(list, 100));
}

test "CollectionMixin - contains" {
    var list = std.ArrayListUnmanaged(u32){};
    defer list.deinit(std.testing.allocator);

    try list.append(std.testing.allocator, 5);
    try list.append(std.testing.allocator, 10);
    try list.append(std.testing.allocator, 15);

    const Helpers = CollectionMixin(u32);
    try std.testing.expect(Helpers.contains(list, 10));
    try std.testing.expect(!Helpers.contains(list, 7));
}

test "StringCollectionMixin - containsString" {
    var list = std.ArrayListUnmanaged([]const u8){};
    defer list.deinit(std.testing.allocator);

    try list.append(std.testing.allocator, "hello");
    try list.append(std.testing.allocator, "world");

    try std.testing.expect(StringCollectionMixin.containsString(list, "hello"));
    try std.testing.expect(StringCollectionMixin.containsString(list, "world"));
    try std.testing.expect(!StringCollectionMixin.containsString(list, "foo"));
}
