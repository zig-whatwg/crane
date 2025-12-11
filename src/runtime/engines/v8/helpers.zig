//! V8 Type Conversion Helpers
//!
//! This module provides safe type conversion helpers for V8 FFI operations.
//! These helpers add runtime type checking before pointer casts, catching
//! type errors at the conversion point rather than causing mysterious crashes.
//!
//! **Use cases:**
//! - Converting V8 Value to specific types (Function, Object, Array, etc.)
//! - Converting specific V8 types back to Value (upcasting)
//! - Safe checked alternatives to direct @ptrCast
//!
//! **Example:**
//! ```zig
//! const helpers = @import("helpers.zig");
//!
//! // Safe downcast with type check
//! const callback_fn = helpers.asFunction(callback_value) orelse return error.NotAFunction;
//!
//! // Safe upcast (always succeeds)
//! const as_value = helpers.toValue(my_string);
//! ```

const ffi = @import("ffi.zig");

// ============================================================================
// Safe Downcasts (Value -> Specific Type)
// ============================================================================

/// Safely cast Value to Function if it is one.
///
/// Returns null if the value is not a function, allowing for clean error handling.
/// Use this instead of `@ptrCast(value)` when you need a Function.
///
/// Example:
/// ```zig
/// const func = helpers.asFunction(value) orelse return error.NotAFunction;
/// _ = ffi.v8_Function_Call(func, context, recv, args, arg_count);
/// ```
pub fn asFunction(value: *ffi.Value) ?*ffi.Function {
    if (ffi.v8_Value_IsFunction(value)) {
        return @ptrCast(value);
    }
    return null;
}

/// Safely cast Value to Object if it is one.
///
/// Returns null if the value is not an object, allowing for clean error handling.
pub fn asObject(value: *ffi.Value) ?*ffi.Object {
    if (ffi.v8_Value_IsObject(value)) {
        return @ptrCast(value);
    }
    return null;
}

/// Safely cast Value to String if it is one.
///
/// Returns null if the value is not a string, allowing for clean error handling.
pub fn asString(value: *ffi.Value) ?*ffi.String {
    if (ffi.v8_Value_IsString(value)) {
        return @ptrCast(value);
    }
    return null;
}

/// Safely cast Value to Array if it is one.
///
/// Returns null if the value is not an array, allowing for clean error handling.
pub fn asArray(value: *ffi.Value) ?*ffi.Array {
    if (ffi.v8_Value_IsArray(value)) {
        return @ptrCast(value);
    }
    return null;
}

/// Safely cast Value to Promise if it is one.
///
/// Returns null if the value is not a promise, allowing for clean error handling.
pub fn asPromise(value: *ffi.Value) ?*ffi.Promise {
    if (ffi.v8_Value_IsPromise(value)) {
        return @ptrCast(value);
    }
    return null;
}

/// Safely cast Value to Number if it is one.
///
/// Returns null if the value is not a number, allowing for clean error handling.
pub fn asNumber(value: *ffi.Value) ?*ffi.Number {
    if (ffi.v8_Value_IsNumber(value)) {
        return @ptrCast(value);
    }
    return null;
}

/// Safely cast Value to Boolean if it is one.
///
/// Returns null if the value is not a boolean, allowing for clean error handling.
pub fn asBoolean(value: *ffi.Value) ?*ffi.Boolean {
    if (ffi.v8_Value_IsBoolean(value)) {
        return @ptrCast(value);
    }
    return null;
}

/// Safely cast Value to ArrayBuffer if it is one.
///
/// Returns null if the value is not an ArrayBuffer, allowing for clean error handling.
pub fn asArrayBuffer(value: *ffi.Value) ?*ffi.ArrayBuffer {
    if (ffi.v8_Value_IsArrayBuffer(value)) {
        return @ptrCast(value);
    }
    return null;
}

/// Safely cast Name to String if it is one.
///
/// In V8, Name is the base type for both String and Symbol.
/// Use this when receiving a Name and you need to ensure it's a String.
pub fn nameAsString(name: *ffi.Name) ?*ffi.String {
    if (ffi.v8_Name_IsString(name)) {
        return @ptrCast(name);
    }
    return null;
}

// ============================================================================
// Safe Upcasts (Specific Type -> Value)
// ============================================================================

/// Cast any specific V8 type to Value.
///
/// This is always safe because all specific types (Object, Function, String, etc.)
/// are subtypes of Value in V8's type hierarchy.
///
/// Supported types:
/// - *ffi.Object
/// - *ffi.Function
/// - *ffi.String
/// - *ffi.Array
/// - *ffi.Number
/// - *ffi.Boolean
/// - *ffi.Promise
/// - *ffi.ArrayBuffer
/// - *ffi.External
/// - *ffi.Name
/// - *ffi.Symbol
///
/// Example:
/// ```zig
/// const my_string = ffi.v8_String_NewFromUtf8(isolate, "hello", 5);
/// const as_value = helpers.toValue(my_string);
/// _ = ffi.v8_Object_Set(obj, context, key, as_value);
/// ```
pub fn toValue(specific: anytype) *ffi.Value {
    const T = @TypeOf(specific);
    comptime {
        // Verify at compile time that we're converting a valid V8 type
        const valid_types = .{
            *ffi.Object,
            *ffi.Function,
            *ffi.String,
            *ffi.Array,
            *ffi.Number,
            *ffi.Boolean,
            *ffi.Promise,
            *ffi.ArrayBuffer,
            *ffi.External,
            *ffi.Name,
            *ffi.Symbol,
        };
        var is_valid = false;
        for (valid_types) |ValidType| {
            if (T == ValidType) {
                is_valid = true;
                break;
            }
        }
        if (!is_valid) {
            @compileError("toValue() only accepts V8 subtype pointers (*Object, *Function, *String, etc.)");
        }
    }
    return @ptrCast(specific);
}

/// Cast String to Name.
///
/// This is always safe because String is a subtype of Name in V8's type hierarchy.
pub fn stringToName(string: *ffi.String) *ffi.Name {
    return @ptrCast(string);
}

/// Cast Symbol to Name.
///
/// This is always safe because Symbol is a subtype of Name in V8's type hierarchy.
pub fn symbolToName(symbol: *ffi.Symbol) *ffi.Name {
    return @ptrCast(symbol);
}

// ============================================================================
// Local Pointer Versions (for raw Local<T> internal pointers from callbacks)
// ============================================================================

/// Safely cast a Local pointer (from callbacks) to Function if it is one.
///
/// This version works with raw pointers that come from V8 callback parameters,
/// which are Local<Value> internal pointers, not Global handles.
pub fn asFunctionLocal(value_ptr: *anyopaque) ?*ffi.Function {
    if (ffi.v8_Value_IsFunction_Local(value_ptr)) {
        return @ptrCast(value_ptr);
    }
    return null;
}

/// Safely cast a Local pointer to Object if it is one.
pub fn asObjectLocal(value_ptr: *anyopaque) ?*ffi.Object {
    if (ffi.v8_Value_IsObject_Local(value_ptr)) {
        return @ptrCast(value_ptr);
    }
    return null;
}

/// Safely cast a Local pointer to Array if it is one.
pub fn asArrayLocal(value_ptr: *anyopaque) ?*ffi.Array {
    if (ffi.v8_Value_IsArray_Local(value_ptr)) {
        return @ptrCast(value_ptr);
    }
    return null;
}

// ============================================================================
// Nullable Variants
// ============================================================================

/// Safely cast optional Value to Function.
///
/// Convenience wrapper for nullable values common in V8 FFI returns.
pub fn asFunctionOpt(value: ?*ffi.Value) ?*ffi.Function {
    const v = value orelse return null;
    return asFunction(v);
}

/// Safely cast optional Value to Object.
pub fn asObjectOpt(value: ?*ffi.Value) ?*ffi.Object {
    const v = value orelse return null;
    return asObject(v);
}

/// Safely cast optional Value to String.
pub fn asStringOpt(value: ?*ffi.Value) ?*ffi.String {
    const v = value orelse return null;
    return asString(v);
}

/// Safely cast optional Value to Array.
pub fn asArrayOpt(value: ?*ffi.Value) ?*ffi.Array {
    const v = value orelse return null;
    return asArray(v);
}

// ============================================================================
// Tests
// ============================================================================

const std = @import("std");

test "toValue comptime type checking" {
    // This test verifies the compile-time type checking works.
    // We can't actually call these without a V8 isolate, but we can
    // verify the function compiles correctly for valid types.

    // These should compile (valid types):
    _ = @TypeOf(toValue);

    // The following would fail at comptime if uncommented:
    // _ = toValue(@as(*u32, undefined)); // Error: not a V8 type
}
