//! Zero-Copy Decode Result
//!
//! Allows returning borrowed slices instead of always allocating,
//! providing "infinite speedup" for the common case (valid UTF-8 input).
//!
//! This is an opt-in optimization - the default `decode()` API still
//! always allocates for API compatibility.

const std = @import("std");

/// Decode result that can be either borrowed (zero-copy) or owned (allocated).
///
/// Use this for maximum performance when you can handle borrowed data.
///
/// Example:
/// ```zig
/// var decoder = try TextDecoder.init(allocator, "utf-8", .{});
/// defer decoder.deinit();
///
/// const result = try decoder.decodeNoCopy(input, .{});
/// defer result.deinit(allocator);
///
/// const text = result.slice();  // Works for both borrowed and owned
/// ```
pub const DecodeResult = union(enum) {
    /// Borrowed from input (zero-copy) - input was valid UTF-8
    borrowed: []const u8,

    /// Owned by result (allocated) - had to clean/convert
    owned: []u8,

    /// Get the decoded string slice (works for both variants)
    pub fn slice(self: *const @This()) []const u8 {
        return switch (self.*) {
            .borrowed => |s| s,
            .owned => |s| s,
        };
    }

    /// Free resources (only frees if owned)
    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        switch (self) {
            .borrowed => {}, // Nothing to free
            .owned => |s| allocator.free(s),
        }
    }

    /// Check if this result is zero-copy (borrowed)
    pub fn isZeroCopy(self: *const @This()) bool {
        return self.* == .borrowed;
    }

    /// Check if this result is heap-allocated (owned)
    pub fn isOwned(self: *const @This()) bool {
        return self.* == .owned;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "DecodeResult - borrowed variant" {
    const input = "Hello, World!";
    const result = DecodeResult{ .borrowed = input };

    try std.testing.expect(result.isZeroCopy());
    try std.testing.expect(!result.isOwned());
    try std.testing.expectEqualStrings("Hello, World!", result.slice());

    // deinit should be safe (no-op for borrowed)
    result.deinit(std.testing.allocator);
}

test "DecodeResult - owned variant" {
    const allocator = std.testing.allocator;

    const input = try allocator.dupe(u8, "Allocated");
    const result = DecodeResult{ .owned = input };

    try std.testing.expect(!result.isZeroCopy());
    try std.testing.expect(result.isOwned());
    try std.testing.expectEqualStrings("Allocated", result.slice());

    // deinit should free memory
    result.deinit(allocator);
}

test "DecodeResult - slice works for both variants" {
    const borrowed = DecodeResult{ .borrowed = "Borrowed" };
    try std.testing.expectEqualStrings("Borrowed", borrowed.slice());

    const allocator = std.testing.allocator;
    const owned_data = try allocator.dupe(u8, "Owned");
    const owned = DecodeResult{ .owned = owned_data };
    try std.testing.expectEqualStrings("Owned", owned.slice());
    owned.deinit(allocator);
}
