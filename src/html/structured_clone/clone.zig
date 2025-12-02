//! structuredClone() API Implementation
//!
//! Spec: HTML Standard §2.7.9 Structured cloning API
//! https://html.spec.whatwg.org/#structured-cloning
//!
//! ## Overview
//!
//! This module provides the high-level structuredClone() method that is exposed
//! to JavaScript. It performs a deep copy of a value, optionally transferring
//! specified objects.
//!
//! ## Usage
//!
//! ```zig
//! const clone = @import("clone.zig");
//!
//! // Clone without transfer
//! const cloned = try clone.structuredClone(allocator, value, null);
//!
//! // Clone with transfer list
//! const cloned_with_transfer = try clone.structuredClone(allocator, value, &transfer_list);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const serialize = @import("serialize.zig");
const deserialize = @import("deserialize.zig");
const transfer = @import("transfer.zig");
const CloneError = types.CloneError;
const JSValue = serialize.JSValue;
const Transferable = transfer.Transferable;

/// structuredClone(value, options)
///
/// Per HTML Standard §2.7.9:
/// Takes the input value and returns a deep copy by performing the
/// structured clone algorithm. Transferable objects listed in the
/// transfer array are transferred, not just cloned, meaning that
/// they are no longer usable in the input value.
///
/// ## Parameters
///
/// - `allocator`: Memory allocator for the cloned value
/// - `value`: The value to clone
/// - `transfer_list`: Optional list of objects to transfer (not copy)
///
/// ## Returns
///
/// A deep copy of the input value, or an error if cloning fails.
///
/// ## Errors
///
/// - `DataCloneError`: Value is not cloneable (functions, symbols, etc.)
/// - `TransferError`: Transfer failed (already detached, duplicate, etc.)
/// - `OutOfMemory`: Memory allocation failed
pub fn structuredClone(
    allocator: Allocator,
    value: *const JSValue,
    transfer_list: ?[]Transferable,
) CloneError!*JSValue {
    if (transfer_list) |transfers| {
        // With transfer: use StructuredSerializeWithTransfer
        var result = try transfer.structuredSerializeWithTransfer(
            allocator,
            value,
            transfers,
        );
        defer result.deinit();

        var deserialize_result = try transfer.structuredDeserializeWithTransfer(
            allocator,
            &result,
        );
        defer deserialize_result.transferred_values.deinit();

        // The deserialized value is a JSValue pointer
        return @ptrCast(@alignCast(deserialize_result.deserialized));
    } else {
        // Without transfer: simple serialize/deserialize
        const serialized = try serialize.structuredSerialize(allocator, value);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }

        return deserialize.structuredDeserialize(allocator, serialized);
    }
}

/// Options for structuredClone (matches JavaScript API)
pub const StructuredCloneOptions = struct {
    transfer: ?[]Transferable = null,
};

/// structuredClone with options object
///
/// This matches the JavaScript API signature:
/// `structuredClone(value, { transfer: [...] })`
pub fn structuredCloneWithOptions(
    allocator: Allocator,
    value: *const JSValue,
    options: StructuredCloneOptions,
) CloneError!*JSValue {
    return structuredClone(allocator, value, options.transfer);
}

// ============================================================================
// High-level convenience functions
// ============================================================================

/// Clone a simple primitive value
pub fn clonePrimitive(allocator: Allocator, value: *const JSValue) CloneError!*JSValue {
    return structuredClone(allocator, value, null);
}

/// Clone an object/array (deep copy)
pub fn cloneObject(allocator: Allocator, value: *const JSValue) CloneError!*JSValue {
    return structuredClone(allocator, value, null);
}

/// Check if a value can be cloned
pub fn isCloneable(value: *const JSValue) bool {
    return switch (value.*) {
        .undefined,
        .null,
        .boolean,
        .number,
        .bigint,
        .string,
        .boolean_object,
        .number_object,
        .bigint_object,
        .string_object,
        .date,
        .regexp,
        .array_buffer,
        .typed_array,
        .data_view,
        .map,
        .set,
        .error_obj,
        .array,
        .object,
        .blob,
        .file,
        .image_data,
        .dom_exception,
        .dom_point,
        .dom_rect,
        => true,

        // Not cloneable
        .symbol, .function => false,
    };
}

/// Check if a value is transferable
pub fn isTransferable(comptime T: type) bool {
    return T == transfer.TransferableArrayBuffer or
        T == transfer.TransferableMessagePort or
        T == transfer.TransferableReadableStream or
        T == transfer.TransferableWritableStream or
        T == transfer.TransferableTransformStream or
        T == transfer.TransferableImageBitmap or
        T == transfer.TransferableOffscreenCanvas;
}

// ============================================================================
// Tests
// ============================================================================

test "structuredClone - primitives" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test boolean
    {
        const value = JSValue{ .boolean = true };
        const cloned = try structuredClone(allocator, &value, null);
        defer deserialize.freeJSValue(allocator, cloned);

        try testing.expectEqual(true, cloned.boolean);
    }

    // Test number
    {
        const value = JSValue{ .number = 3.14159 };
        const cloned = try structuredClone(allocator, &value, null);
        defer deserialize.freeJSValue(allocator, cloned);

        try testing.expectEqual(@as(f64, 3.14159), cloned.number);
    }

    // Test string
    {
        const value = JSValue{ .string = "hello clone" };
        const cloned = try structuredClone(allocator, &value, null);
        defer deserialize.freeJSValue(allocator, cloned);

        try testing.expectEqualStrings("hello clone", cloned.string);
    }
}

test "structuredClone - Date" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const timestamp: f64 = 1700000000000;
    const value = JSValue{ .date = timestamp };
    const cloned = try structuredClone(allocator, &value, null);
    defer deserialize.freeJSValue(allocator, cloned);

    try testing.expectEqual(timestamp, cloned.date);
}

test "structuredClone - symbol throws DataCloneError" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const value = JSValue{ .symbol = {} };
    const result = structuredClone(allocator, &value, null);
    try testing.expectError(CloneError.DataCloneError, result);
}

test "structuredClone - function throws DataCloneError" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const value = JSValue{ .function = {} };
    const result = structuredClone(allocator, &value, null);
    try testing.expectError(CloneError.DataCloneError, result);
}

test "isCloneable" {
    const testing = std.testing;

    // Cloneable types
    try testing.expect(isCloneable(&JSValue{ .boolean = true }));
    try testing.expect(isCloneable(&JSValue{ .number = 42 }));
    try testing.expect(isCloneable(&JSValue{ .string = "test" }));
    try testing.expect(isCloneable(&JSValue{ .date = 0 }));

    // Non-cloneable types
    try testing.expect(!isCloneable(&JSValue{ .symbol = {} }));
    try testing.expect(!isCloneable(&JSValue{ .function = {} }));
}
