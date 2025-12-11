//! V8 Array Creation Utilities
//!
//! High-level utilities for creating V8 Arrays from Zig data types.
//! These utilities are used by WebIDL impls that need to return sequences
//! (arrays) to JavaScript.
//!
//! ## Supported Array Types
//!
//! - Arrays of runtime.Instance pointers (WebIDL interfaces)
//! - Arrays of strings (DOMString, ByteString, USVString)
//! - Arrays of any type supported by toV8Value
//!
//! ## Usage
//!
//! ```zig
//! const array_utils = @import("array_utils.zig");
//!
//! // Create array of instances
//! const instances: []const *runtime.Instance = &[_]*runtime.Instance{ elem1, elem2 };
//! const v8_array = try array_utils.createInstanceArray(isolate, context, instances);
//!
//! // Create array of strings
//! const strings: []const []const u8 = &[_][]const u8{ "foo", "bar" };
//! const v8_string_array = try array_utils.createStringArray(isolate, context, strings);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const conversions = @import("conversions.zig");

pub const ArrayCreationError = error{
    /// Failed to create the V8 Array
    ArrayCreationFailed,
    /// Failed to create a V8 String
    StringCreationFailed,
    /// Failed to convert an element to V8
    ElementConversionFailed,
    /// Failed to set an element in the array
    ArraySetFailed,
    /// No V8 isolate available
    NoIsolate,
    /// No V8 context available
    NoContext,
};

/// Create a V8 Array from a slice of runtime.Instance pointers.
///
/// Each instance is wrapped as a proper V8 object using the template registry,
/// ensuring the correct prototype chain is established.
///
/// Example:
/// ```zig
/// const composed_path: []const *runtime.Instance = path.toSlice();
/// const v8_array = try createInstanceArray(isolate, context, composed_path);
/// return runtime.JSValue.fromHandle(@ptrCast(v8_array));
/// ```
pub fn createInstanceArray(
    isolate: *v8.Isolate,
    context: *v8.Context,
    instances: []const *runtime.Instance,
) ArrayCreationError!*v8.Array {
    const array = v8.v8_Array_New(isolate, @intCast(instances.len));

    for (instances, 0..) |instance, i| {
        const v8_value = conversions.instanceToV8(isolate, instance);
        if (!v8.v8_Array_Set(array, context, @intCast(i), v8_value)) {
            return ArrayCreationError.ArraySetFailed;
        }
    }

    return array;
}

/// Create a V8 Array from a slice of strings.
///
/// Each string is converted to a V8 String value.
///
/// Example:
/// ```zig
/// const headers: []const []const u8 = &[_][]const u8{ "Set-Cookie: a=1", "Set-Cookie: b=2" };
/// const v8_array = try createStringArray(isolate, context, headers);
/// ```
pub fn createStringArray(
    isolate: *v8.Isolate,
    context: *v8.Context,
    strings: []const []const u8,
) ArrayCreationError!*v8.Array {
    const array = v8.v8_Array_New(isolate, @intCast(strings.len));

    for (strings, 0..) |str, i| {
        const v8_string = if (str.len == 0)
            v8.v8_String_Empty(isolate) orelse return ArrayCreationError.StringCreationFailed
        else
            v8.v8_String_NewFromUtf8(isolate, str.ptr, @intCast(str.len)) orelse
                return ArrayCreationError.StringCreationFailed;

        if (!v8.v8_Array_Set(array, context, @intCast(i), @ptrCast(v8_string))) {
            return ArrayCreationError.ArraySetFailed;
        }
    }

    return array;
}

/// Create a V8 Array from a slice of DOMString values.
///
/// Example:
/// ```zig
/// const names: []const runtime.DOMString = &[_]runtime.DOMString{
///     runtime.DOMString.initInterned("Alice"),
///     runtime.DOMString.initInterned("Bob"),
/// };
/// const v8_array = try createDOMStringArray(isolate, context, names);
/// ```
pub fn createDOMStringArray(
    isolate: *v8.Isolate,
    context: *v8.Context,
    strings: []const runtime.DOMString,
) ArrayCreationError!*v8.Array {
    const array = v8.v8_Array_New(isolate, @intCast(strings.len));

    for (strings, 0..) |dom_string, i| {
        const slice = dom_string.asSlice();
        const v8_string = if (slice.len == 0)
            v8.v8_String_Empty(isolate) orelse return ArrayCreationError.StringCreationFailed
        else
            v8.v8_String_NewFromUtf8(isolate, slice.ptr, @intCast(slice.len)) orelse
                return ArrayCreationError.StringCreationFailed;

        if (!v8.v8_Array_Set(array, context, @intCast(i), @ptrCast(v8_string))) {
            return ArrayCreationError.ArraySetFailed;
        }
    }

    return array;
}

/// Create a V8 Array of a fixed size (2 elements) - useful for tee() return.
///
/// Example:
/// ```zig
/// const branch1 = try ReadableStream.init(allocator, ctx);
/// const branch2 = try ReadableStream.init(allocator, ctx);
/// const v8_array = try createPair(isolate, context, branch1, branch2);
/// ```
pub fn createPair(
    isolate: *v8.Isolate,
    context: *v8.Context,
    first: *runtime.Instance,
    second: *runtime.Instance,
) ArrayCreationError!*v8.Array {
    const array = v8.v8_Array_New(isolate, 2);

    const v8_first = conversions.instanceToV8(isolate, first);
    if (!v8.v8_Array_Set(array, context, 0, v8_first)) {
        return ArrayCreationError.ArraySetFailed;
    }

    const v8_second = conversions.instanceToV8(isolate, second);
    if (!v8.v8_Array_Set(array, context, 1, v8_second)) {
        return ArrayCreationError.ArraySetFailed;
    }

    return array;
}

/// Create an empty V8 Array.
///
/// Useful for methods that need to return an empty sequence.
pub fn createEmptyArray(isolate: *v8.Isolate) *v8.Array {
    return v8.v8_Array_New(isolate, 0);
}

/// Get the current V8 isolate, returning error if not available.
pub fn getCurrentIsolate() ArrayCreationError!*v8.Isolate {
    return v8.v8_Isolate_GetCurrent() orelse return ArrayCreationError.NoIsolate;
}

/// Get the current V8 context, returning error if not available.
pub fn getCurrentContext(isolate: *v8.Isolate) ArrayCreationError!*v8.Context {
    return v8.v8_Isolate_GetCurrentContext(isolate) orelse return ArrayCreationError.NoContext;
}

// ============================================================================
// Tests
// ============================================================================

test "createEmptyArray" {
    // This test requires V8 initialization which we can't do in unit tests
    // It serves as documentation for the API
}
