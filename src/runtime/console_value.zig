//! Console Value Type
//!
//! Represents any JavaScript value that can be logged to the console.
//! This is used by the Console API implementation to handle variadic arguments
//! of any type.

const std = @import("std");
const types = @import("types.zig");

/// A tagged union representing any JavaScript value for console logging
pub const ConsoleValue = union(enum) {
    /// Undefined value
    undefined: void,

    /// Null value
    null: void,

    /// Boolean value
    boolean: bool,

    /// Number value (JavaScript Number is always f64)
    number: f64,

    /// String value (owned, must be freed)
    string: []const u8,

    /// Object (opaque pointer to V8 value for inspection)
    object: *const anyopaque,

    /// Symbol (opaque pointer to V8 value)
    symbol: *const anyopaque,

    /// BigInt (represented as string for now)
    bigint: []const u8,

    /// Deinitialize the value (frees owned memory)
    pub fn deinit(self: ConsoleValue, allocator: std.mem.Allocator) void {
        switch (self) {
            .string => |s| allocator.free(s),
            .bigint => |s| allocator.free(s),
            else => {},
        }
    }

    /// Format the value for printing
    /// Allocates a string representation that must be freed by caller
    pub fn toString(self: ConsoleValue, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .undefined => try allocator.dupe(u8, "undefined"),
            .null => try allocator.dupe(u8, "null"),
            .boolean => |b| if (b) try allocator.dupe(u8, "true") else try allocator.dupe(u8, "false"),
            .number => |n| blk: {
                // Handle special number values
                if (std.math.isNan(n)) {
                    break :blk try allocator.dupe(u8, "NaN");
                } else if (std.math.isInf(n)) {
                    break :blk if (n > 0)
                        try allocator.dupe(u8, "Infinity")
                    else
                        try allocator.dupe(u8, "-Infinity");
                } else {
                    // Format number as string
                    break :blk try std.fmt.allocPrint(allocator, "{d}", .{n});
                }
            },
            .string => |s| try allocator.dupe(u8, s),
            .object => try allocator.dupe(u8, "[object Object]"),
            .symbol => try allocator.dupe(u8, "Symbol()"),
            .bigint => |s| try std.fmt.allocPrint(allocator, "{s}n", .{s}),
        };
    }

    /// Get the type name of the value
    pub fn typeName(self: ConsoleValue) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .null => "null",
            .boolean => "boolean",
            .number => "number",
            .string => "string",
            .object => "object",
            .symbol => "symbol",
            .bigint => "bigint",
        };
    }
};

// Tests
test "ConsoleValue - undefined" {
    const value = ConsoleValue{ .undefined = {} };
    const str = try value.toString(std.testing.allocator);
    defer std.testing.allocator.free(str);
    try std.testing.expectEqualStrings("undefined", str);
    try std.testing.expectEqualStrings("undefined", value.typeName());
}

test "ConsoleValue - null" {
    const value = ConsoleValue{ .null = {} };
    const str = try value.toString(std.testing.allocator);
    defer std.testing.allocator.free(str);
    try std.testing.expectEqualStrings("null", str);
    try std.testing.expectEqualStrings("null", value.typeName());
}

test "ConsoleValue - boolean" {
    const t = ConsoleValue{ .boolean = true };
    const f = ConsoleValue{ .boolean = false };

    const t_str = try t.toString(std.testing.allocator);
    defer std.testing.allocator.free(t_str);
    try std.testing.expectEqualStrings("true", t_str);

    const f_str = try f.toString(std.testing.allocator);
    defer std.testing.allocator.free(f_str);
    try std.testing.expectEqualStrings("false", f_str);
}

test "ConsoleValue - number" {
    const num = ConsoleValue{ .number = 42.5 };
    const str = try num.toString(std.testing.allocator);
    defer std.testing.allocator.free(str);
    try std.testing.expect(std.mem.indexOf(u8, str, "42.5") != null);
}

test "ConsoleValue - NaN" {
    const nan = ConsoleValue{ .number = std.math.nan(f64) };
    const str = try nan.toString(std.testing.allocator);
    defer std.testing.allocator.free(str);
    try std.testing.expectEqualStrings("NaN", str);
}

test "ConsoleValue - Infinity" {
    const inf = ConsoleValue{ .number = std.math.inf(f64) };
    const str = try inf.toString(std.testing.allocator);
    defer std.testing.allocator.free(str);
    try std.testing.expectEqualStrings("Infinity", str);
}

test "ConsoleValue - string" {
    const value = ConsoleValue{ .string = "hello" };
    const str = try value.toString(std.testing.allocator);
    defer std.testing.allocator.free(str);
    try std.testing.expectEqualStrings("hello", str);
}
