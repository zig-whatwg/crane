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









