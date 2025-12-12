//! Typed Dictionary/Sequence Extraction Utilities
//!
//! This module provides type-safe extraction of dictionary and sequence types
//! from opaque pointers, eliminating the need for manual @ptrCast/@alignCast.
//!
//! ## Problem
//!
//! WebIDL dictionary arrays passed through the bindings layer often arrive
//! as anyopaque pointers that need unsafe casting:
//!
//! ```zig
//! // Unsafe pattern - manual casts can hide type errors
//! const subs_ptr = value.toAnyopaque() orelse return error.TypeError;
//! const subs_slice = @as(*const []const MyDictionary, @ptrCast(@alignCast(subs_ptr)));
//! ```
//!
//! ## Solution
//!
//! Use typed extraction functions:
//!
//! ```zig
//! const extraction = @import("webidl").utils.typed_extraction;
//!
//! // Type-safe extraction
//! const subscriptions = try extraction.extractDictionarySlice(
//!     dictionaries.CookieStoreGetOptions,
//!     subscriptions_value,
//! );
//! for (subscriptions) |sub| {
//!     // ...
//! }
//! ```

const std = @import("std");

/// Extract a typed dictionary slice from a JSValue containing an anyopaque pointer.
///
/// This is a type-safe wrapper around the unsafe pointer casting pattern used
/// when extracting dictionary arrays from JS bindings.
///
/// Returns error.TypeError if the value cannot be converted to the expected type.
///
/// Example:
/// ```zig
/// const subs = try extractDictionarySlice(CookieStoreGetOptions, subscriptions_value);
/// for (subs) |sub| {
///     // Access sub.name, sub.url, etc. with full type safety
/// }
/// ```
pub fn extractDictionarySlice(
    comptime DictionaryType: type,
    opaque_ptr: ?*anyopaque,
) error{TypeError}![]const DictionaryType {
    const ptr = opaque_ptr orelse return error.TypeError;
    const typed_ptr: *const []const DictionaryType = @ptrCast(@alignCast(ptr));
    return typed_ptr.*;
}

/// Extract a typed dictionary slice from an optional anyopaque pointer.
///
/// Returns null if the input pointer is null, otherwise extracts the typed slice.
/// This is useful for optional dictionary members.
///
/// Example:
/// ```zig
/// if (try extractOptionalDictionarySlice(CookieListItem, init_dict.changed)) |changed| {
///     for (changed) |item| {
///         // Process item
///     }
/// }
/// ```
pub fn extractOptionalDictionarySlice(
    comptime DictionaryType: type,
    opaque_ptr: ?*const anyopaque,
) error{TypeError}!?[]const DictionaryType {
    const ptr = opaque_ptr orelse return null;
    const typed_ptr: *const []const DictionaryType = @ptrCast(@alignCast(ptr));
    return typed_ptr.*;
}

/// Extract a single typed dictionary from an anyopaque pointer.
///
/// Example:
/// ```zig
/// const options = try extractDictionary(MyOptions, options_ptr);
/// ```
pub fn extractDictionary(
    comptime DictionaryType: type,
    opaque_ptr: ?*anyopaque,
) error{TypeError}!*const DictionaryType {
    const ptr = opaque_ptr orelse return error.TypeError;
    return @ptrCast(@alignCast(ptr));
}

/// Extract an optional single typed dictionary from an anyopaque pointer.
///
/// Returns null if the input pointer is null.
pub fn extractOptionalDictionary(
    comptime DictionaryType: type,
    opaque_ptr: ?*const anyopaque,
) ?*const DictionaryType {
    const ptr = opaque_ptr orelse return null;
    return @ptrCast(@alignCast(ptr));
}

// ============================================================================
// Tests
// ============================================================================

test "extractDictionarySlice - extracts typed slice" {
    const TestDict = struct {
        name: ?[]const u8,
        value: u32,
    };

    var items = [_]TestDict{
        .{ .name = "foo", .value = 1 },
        .{ .name = "bar", .value = 2 },
    };
    const slice: []const TestDict = &items;
    const ptr: *const []const TestDict = &slice;
    const opaque_ptr: *anyopaque = @ptrCast(@constCast(ptr));

    const result = try extractDictionarySlice(TestDict, opaque_ptr);
    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualStrings("foo", result[0].name.?);
    try std.testing.expectEqual(@as(u32, 2), result[1].value);
}

test "extractDictionarySlice - null returns TypeError" {
    const TestDict = struct { x: u32 };
    const result = extractDictionarySlice(TestDict, null);
    try std.testing.expectError(error.TypeError, result);
}

test "extractOptionalDictionarySlice - null returns null" {
    const TestDict = struct { x: u32 };
    const result = try extractOptionalDictionarySlice(TestDict, null);
    try std.testing.expectEqual(@as(?[]const TestDict, null), result);
}

test "extractDictionary - extracts single dictionary" {
    const TestDict = struct {
        name: []const u8,
        count: u32,
    };

    const dict = TestDict{ .name = "test", .count = 42 };
    const ptr: *const TestDict = &dict;
    const opaque_ptr: *anyopaque = @ptrCast(@constCast(ptr));

    const result = try extractDictionary(TestDict, opaque_ptr);
    try std.testing.expectEqualStrings("test", result.name);
    try std.testing.expectEqual(@as(u32, 42), result.count);
}
