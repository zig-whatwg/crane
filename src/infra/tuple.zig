//! WHATWG Infra Tuple Operations
//!
//! Spec: https://infra.spec.whatwg.org/#tuple
//!
//! A tuple is a finite ordered sequence of items. In Zig, Infra tuples
//! map to anonymous structs (Zig tuples) with indexed fields.
//!
//! # Design
//!
//! Infra tuples are compile-time defined types in Zig. The spec describes
//! tuples as "a finite ordered list of items", which maps naturally to
//! Zig's tuple type system (anonymous structs).
//!
//! # Usage
//!
//! ```zig
//! // Define a tuple (anonymous struct)
//! const tuple = .{ "hello", 42, true };
//!
//! // Access by index
//! const first = tuple[0];   // "hello"
//! const second = tuple[1];  // 42
//! const third = tuple[2];   // true
//!
//! // Type-safe tuples
//! const typed_tuple: struct { []const u8, u32, bool } = .{ "world", 100, false };
//! ```
//!
//! # Note
//!
//! Since Infra tuples map directly to Zig tuples (anonymous structs),
//! there's no need for additional wrapper types. This module exists
//! primarily for documentation and to provide helper utilities if needed.

const std = @import("std");

test "tuple - basic usage" {
    const tuple = .{ 42, "hello", true };

    try std.testing.expectEqual(@as(comptime_int, 42), tuple[0]);
    try std.testing.expectEqualStrings("hello", tuple[1]);
    try std.testing.expectEqual(true, tuple[2]);
}

test "tuple - typed tuple" {
    const TypedTuple = std.meta.Tuple(&[_]type{ u32, []const u8, bool });
    const tuple: TypedTuple = .{ 42, "hello", true };

    try std.testing.expectEqual(@as(u32, 42), tuple[0]);
    try std.testing.expectEqualStrings("hello", tuple[1]);
    try std.testing.expectEqual(true, tuple[2]);
}

test "tuple - nested tuples" {
    const outer = .{ .{ 1, 2 }, .{ 3, 4 } };

    try std.testing.expectEqual(@as(comptime_int, 1), outer[0][0]);
    try std.testing.expectEqual(@as(comptime_int, 2), outer[0][1]);
    try std.testing.expectEqual(@as(comptime_int, 3), outer[1][0]);
    try std.testing.expectEqual(@as(comptime_int, 4), outer[1][1]);
}

test "tuple - length" {
    const tuple1 = .{ 1, 2, 3 };
    const tuple2 = .{ "a", "b" };

    try std.testing.expectEqual(@as(usize, 3), tuple1.len);
    try std.testing.expectEqual(@as(usize, 2), tuple2.len);
}

test "tuple - iteration" {
    const tuple = .{ 10, 20, 30 };
    var sum: u32 = 0;

    inline for (tuple) |value| {
        sum += value;
    }

    try std.testing.expectEqual(@as(u32, 60), sum);
}

test "tuple - mixed types" {
    const mixed = .{ @as(u8, 255), @as(u16, 1000), @as(u32, 100000) };

    try std.testing.expectEqual(@as(u8, 255), mixed[0]);
    try std.testing.expectEqual(@as(u16, 1000), mixed[1]);
    try std.testing.expectEqual(@as(u32, 100000), mixed[2]);
}

test "tuple - destructuring" {
    const tuple = .{ 42, "hello", true };
    const first, const second, const third = tuple;

    try std.testing.expectEqual(@as(comptime_int, 42), first);
    try std.testing.expectEqualStrings("hello", second);
    try std.testing.expectEqual(true, third);
}

test "tuple - return multiple values" {
    const divide = struct {
        fn div(a: u32, b: u32) struct { u32, u32 } {
            return .{ a / b, a % b };
        }
    }.div;

    const result = divide(10, 3);
    try std.testing.expectEqual(@as(u32, 3), result[0]);
    try std.testing.expectEqual(@as(u32, 1), result[1]);
}
