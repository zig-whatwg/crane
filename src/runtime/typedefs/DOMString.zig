//! DOMString - WebIDL's string type with efficient storage
//!
//! WebIDL DOMString maps to different storage strategies:
//! - empty: Empty string (no allocation)
//! - interned: String from string cache (no free needed)
//! - owned: Allocated string (must be freed)
//!
//! This union allows generated code to avoid allocations for:
//! - Empty strings (common for unset attributes)
//! - Interned strings (common attribute values like "div", "true", "false")
//! - Frequently used strings from a string cache
//!
//! Example:
//!   var str = DOMString{ .owned = try allocator.dupe(u8, "hello") };
//!   defer str.deinit(allocator);

const std = @import("std");

pub const DOMString = union(enum) {
    /// Empty string (no allocation)
    empty: void,

    /// Interned string from cache (no free needed)
    /// The string cache is managed separately
    interned: []const u8,

    /// Owned string (must be freed)
    owned: []const u8,

    /// Initialize an empty DOMString
    pub fn initEmpty() DOMString {
        return .{ .empty = {} };
    }

    /// Initialize from an interned string (no copy, no allocation)
    pub fn initInterned(s: []const u8) DOMString {
        return .{ .interned = s };
    }

    /// Initialize by taking ownership of allocated string
    pub fn initOwned(s: []const u8) DOMString {
        return .{ .owned = s };
    }

    /// Initialize by duplicating a string (allocates)
    pub fn initDupe(allocator: std.mem.Allocator, s: []const u8) !DOMString {
        if (s.len == 0) return initEmpty();
        const owned = try allocator.dupe(u8, s);
        return initOwned(owned);
    }

    /// Free owned string (safe to call on empty/interned)
    pub fn deinit(self: *DOMString, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .owned => |s| allocator.free(s),
            .empty, .interned => {},
        }
        self.* = .{ .empty = {} };
    }

    /// Get the string as a slice (works for all variants)
    pub fn asSlice(self: DOMString) []const u8 {
        return switch (self) {
            .empty => "",
            .interned => |s| s,
            .owned => |s| s,
        };
    }

    /// Check if the string is empty
    pub fn isEmpty(self: DOMString) bool {
        return switch (self) {
            .empty => true,
            .interned => |s| s.len == 0,
            .owned => |s| s.len == 0,
        };
    }

    /// Get the length of the string
    pub fn len(self: DOMString) usize {
        return self.asSlice().len;
    }

    /// Clone the string (allocates new owned string)
    pub fn clone(self: DOMString, allocator: std.mem.Allocator) !DOMString {
        return switch (self) {
            .empty => initEmpty(),
            .interned => |s| initDupe(allocator, s),
            .owned => |s| initDupe(allocator, s),
        };
    }
};

// Unit tests
const testing = std.testing;
const test_allocator = testing.allocator;

test "DOMString.empty works" {
    var str = DOMString.initEmpty();
    defer str.deinit(test_allocator);

    try testing.expectEqualStrings("", str.asSlice());
    try testing.expect(str.isEmpty());
    try testing.expectEqual(@as(usize, 0), str.len());
}

test "DOMString.interned works" {
    const interned = "hello";
    var str = DOMString.initInterned(interned);
    defer str.deinit(test_allocator);

    try testing.expectEqualStrings("hello", str.asSlice());
    try testing.expect(!str.isEmpty());
    try testing.expectEqual(@as(usize, 5), str.len());
}

test "DOMString.owned works" {
    const owned = try test_allocator.dupe(u8, "world");
    var str = DOMString.initOwned(owned);
    defer str.deinit(test_allocator);

    try testing.expectEqualStrings("world", str.asSlice());
    try testing.expect(!str.isEmpty());
    try testing.expectEqual(@as(usize, 5), str.len());
}

test "DOMString.initDupe allocates and copies" {
    var str = try DOMString.initDupe(test_allocator, "test");
    defer str.deinit(test_allocator);

    try testing.expectEqualStrings("test", str.asSlice());
    try testing.expectEqual(@as(usize, 4), str.len());
}

test "DOMString.initDupe handles empty string" {
    var str = try DOMString.initDupe(test_allocator, "");
    defer str.deinit(test_allocator);

    try testing.expect(str.isEmpty());
    try testing.expectEqual(@as(usize, 0), str.len());
}

test "DOMString.clone works" {
    var original = try DOMString.initDupe(test_allocator, "original");
    defer original.deinit(test_allocator);

    var cloned = try original.clone(test_allocator);
    defer cloned.deinit(test_allocator);

    try testing.expectEqualStrings("original", cloned.asSlice());

    // Verify they're different allocations
    try testing.expect(original.asSlice().ptr != cloned.asSlice().ptr);
}

test "DOMString.deinit is safe to call multiple times" {
    var str = DOMString.initEmpty();
    str.deinit(test_allocator); // First deinit
    str.deinit(test_allocator); // Second deinit (should be safe)

    try testing.expect(str.isEmpty());
}
