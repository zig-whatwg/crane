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
