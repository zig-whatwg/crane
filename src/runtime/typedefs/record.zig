//! record<K,V> - Ordered map (key-value pairs)
//!
//! WebIDL record<K, V> represents an ordered map with string keys and values of type V.
//! Per the spec: "A record type is a parameterized type whose values are ordered
//! maps with keys that are instances of K and values that are instances of V.
//! K must be one of DOMString, USVString, or ByteString."
//!
//! Important: Records are always passed by value (copied), not by reference.
//!
//! Note: Per WebIDL spec, "Records must not be used as the type of an attribute
//! or constant." So this type will only appear in operation parameters, return
//! types, and dictionary members.
//!
//! Generic function to create the type (used in generated code):

const std = @import("std");
const DOMString = @import("DOMString.zig").DOMString;
const USVString = @import("USVString.zig").USVString;
const ByteString = @import("ByteString.zig").ByteString;

/// record<K,V> - Ordered map type
pub fn record(comptime K: type, comptime V: type) type {
    // Validate that K is a string type (enforced by WebIDL spec)
    comptime {
        const valid_key = K == DOMString or K == USVString or K == ByteString or
            K == []const u8; // Allow raw string slices too
        if (!valid_key) {
            @compileError("record<K,V> key type must be DOMString, USVString, or ByteString");
        }
    }

    return struct {
        const Self = @This();

        /// Key-value pair entry
        pub const Entry = struct {
            key: K,
            value: V,
        };

        /// Ordered list of entries (maintains insertion order per WebIDL spec)
        /// Allocated and owned by this record
        entries: []Entry,

        /// Allocator used for this record
        allocator: std.mem.Allocator,

        /// Key type
        pub const KeyType = K;

        /// Value type
        pub const ValueType = V;

        /// Initialize an empty record
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .entries = &[_]Entry{},
                .allocator = allocator,
            };
        }

        /// Initialize from a slice of entries (copies the data)
        pub fn initFromEntries(allocator: std.mem.Allocator, entries: []const Entry) !Self {
            const owned_entries = try allocator.dupe(Entry, entries);
            return .{
                .entries = owned_entries,
                .allocator = allocator,
            };
        }

        /// Free all memory used by this record
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.entries);
            self.entries = &[_]Entry{};
        }

        /// Get the number of entries
        pub fn count(self: Self) usize {
            return self.entries.len;
        }

        /// Check if the record is empty
        pub fn isEmpty(self: Self) bool {
            return self.entries.len == 0;
        }

        // TODO: Add more methods:
        // - get(key: K) -> ?V
        // - set(key: K, value: V) -> !void
        // - has(key: K) -> bool
        // - delete(key: K) -> bool
        // - keys() -> Iterator(K)
        // - values() -> Iterator(V)
        // - clone() -> !Self
    };
}
