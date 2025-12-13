//! V8-specific Realm Operations
//!
//! This module provides V8-specific implementations for realm operations.
//! These functions are called by the abstract Realm struct in runtime/realm.zig
//! to perform V8-specific tasks like:
//!
//! - Creating objects/arrays in a specific realm's context
//! - Creating TypeError/RangeError from a specific realm
//! - Populating realm intrinsics from V8 context
//!
//! ## Cross-Realm Support
//!
//! Per WebIDL spec, when methods like toJSON create result objects, the object's
//! prototype must come from the method's realm, not the caller's realm. For example:
//!
//! ```javascript
//! const other = iframe.contentWindow;
//! const rect = new DOMRectReadOnly(1, 2, 3, 4);
//! const json = other.DOMRectReadOnly.prototype.toJSON.call(rect);
//! // json's prototype should be other.Object.prototype, not main.Object.prototype
//! assert_equals(Object.getPrototypeOf(json), other.Object.prototype);
//! ```
//!
//! This module ensures such cross-realm semantics work correctly by creating
//! objects in the correct V8 context.
//!
//! ## Specification References
//!
//! - WebIDL §4.3: toJSON operation realm handling
//! - WebIDL §3.3: Platform objects and realms
//! - HTML §8.1.5: Realms, settings objects, and global objects

const std = @import("std");

// Import from within the v8 module (this file is part of v8 module)
const ffi = @import("ffi.zig");
const conv = @import("conversions.zig");

/// Re-export Realm from runtime for type compatibility
const runtime = @import("runtime");
const Realm = runtime.Realm;

// Alias for convenience (using ffi instead of v8 to avoid confusion)
const v8 = ffi;

// ============================================================================
// Object Creation in Specific Realm
// ============================================================================

/// Create a plain object {} in the specified realm.
///
/// The object's prototype will be the realm's Object.prototype, ensuring
/// correct cross-realm behavior for operations like toJSON.
///
/// @param realm - The realm in which to create the object
/// @return V8 Object pointer (Global handle), or null on failure
pub fn createObjectInRealm(realm: *const Realm) ?*v8.Object {
    const context: *v8.Context = @ptrCast(@alignCast(realm.v8_context orelse return null));
    return v8.v8_Object_NewInContext(context);
}

/// Create an array [] in the specified realm.
///
/// The array's prototype will be the realm's Array.prototype, ensuring
/// correct cross-realm behavior.
///
/// @param realm - The realm in which to create the array
/// @param length - Initial length of the array (default 0)
/// @return V8 Array pointer (Global handle), or null on failure
pub fn createArrayInRealm(realm: *const Realm, length: u32) ?*v8.Array {
    const context: *v8.Context = @ptrCast(@alignCast(realm.v8_context orelse return null));
    return v8.v8_Array_NewInContext(context, @intCast(length));
}

// ============================================================================
// Error Creation in Specific Realm
// ============================================================================

/// Create a TypeError from the specified realm.
///
/// Per WebIDL spec, when a method throws TypeError for invalid `this`,
/// the error must come from the method's realm (callee's realm), not the caller's realm.
///
/// @param realm - The realm from which the TypeError should originate
/// @param message - Error message
/// @return V8 Value pointer (the TypeError), or null on failure
pub fn createTypeErrorInRealm(realm: *const Realm, message: []const u8) ?*v8.Value {
    const context: *v8.Context = @ptrCast(@alignCast(realm.v8_context orelse return null));
    const isolate = v8.v8_Isolate_GetCurrent() orelse return null;

    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse return null;

    return v8.v8_Exception_TypeErrorInContext(context, msg_str);
}

/// Throw a TypeError from the specified realm.
///
/// Creates a TypeError and throws it as a V8 exception.
/// The error comes from the specified realm, not the current context.
///
/// @param realm - The realm from which the TypeError should originate
/// @param message - Error message
pub fn throwTypeErrorFromRealm(realm: *const Realm, message: []const u8) void {
    const context: *v8.Context = @ptrCast(@alignCast(realm.v8_context orelse return));
    const isolate: *v8.Isolate = @ptrCast(@alignCast(realm.isolate orelse {
        // Fallback to current isolate if realm doesn't have one
        const current_isolate = v8.v8_Isolate_GetCurrent() orelse return;
        conv.throwTypeErrorFromContext(current_isolate, context, message);
        return;
    }));

    conv.throwTypeErrorFromContext(isolate, context, message);
}

// ============================================================================
// Intrinsics Population
// ============================================================================

/// Populate a realm's intrinsics from its V8 context.
///
/// This caches the realm's built-in constructors and prototypes (TypeError,
/// Object, Array, etc.) for efficient access when creating errors or objects.
///
/// Intrinsics must be populated before cross-realm operations can work correctly.
/// This should be called after the V8 context is created and entered.
///
/// @param realm - The realm whose intrinsics should be populated
/// @return true on success, false on failure
pub fn populateIntrinsics(realm: *Realm) bool {
    const context: *v8.Context = @ptrCast(@alignCast(realm.v8_context orelse return false));
    const isolate = v8.v8_Isolate_GetCurrent() orelse return false;

    // Get the global object to access built-in constructors
    const global = v8.v8_Context_Global(context) orelse return false;

    var intrinsics = realm.getIntrinsicsMut();

    // Get TypeError constructor
    intrinsics.type_error = getGlobalProperty(isolate, context, global, "TypeError");

    // Get RangeError constructor
    intrinsics.range_error = getGlobalProperty(isolate, context, global, "RangeError");

    // Get SyntaxError constructor
    intrinsics.syntax_error = getGlobalProperty(isolate, context, global, "SyntaxError");

    // Get Object constructor and prototype
    intrinsics.object = getGlobalProperty(isolate, context, global, "Object");
    if (intrinsics.object) |obj_ctor| {
        intrinsics.object_prototype = getObjectProperty(isolate, context, @ptrCast(obj_ctor), "prototype");
    }

    // Get Array constructor and prototype
    intrinsics.array = getGlobalProperty(isolate, context, global, "Array");
    if (intrinsics.array) |arr_ctor| {
        intrinsics.array_prototype = getObjectProperty(isolate, context, @ptrCast(arr_ctor), "prototype");
    }

    // Get Function.prototype
    const function_ctor = getGlobalProperty(isolate, context, global, "Function");
    if (function_ctor) |fn_ctor| {
        intrinsics.function_prototype = getObjectProperty(isolate, context, @ptrCast(fn_ctor), "prototype");
    }

    return intrinsics.isPopulated();
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Get a property from the global object by name.
fn getGlobalProperty(
    isolate: *v8.Isolate,
    context: *v8.Context,
    global: *v8.Object,
    name: []const u8,
) ?*anyopaque {
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return null;
    const value = v8.v8_Object_Get(global, context, @ptrCast(key)) orelse return null;
    return @ptrCast(value);
}

/// Get a property from an object by name.
fn getObjectProperty(
    isolate: *v8.Isolate,
    context: *v8.Context,
    object: *v8.Object,
    name: []const u8,
) ?*anyopaque {
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return null;
    const value = v8.v8_Object_Get(object, context, @ptrCast(key)) orelse return null;
    return @ptrCast(value);
}

// ============================================================================
// Realm Method Implementations
// ============================================================================

/// Get a V8 context from an opaque pointer stored in a Realm.
pub fn getV8Context(realm: *const Realm) ?*v8.Context {
    return @ptrCast(@alignCast(realm.v8_context));
}

/// Get a V8 isolate from an opaque pointer stored in a Realm.
pub fn getV8Isolate(realm: *const Realm) ?*v8.Isolate {
    return @ptrCast(@alignCast(realm.isolate));
}

// ============================================================================
// Tests
// ============================================================================

test "realm_v8 compiles" {
    // This test just verifies the module compiles correctly
    // Actual V8 tests require a running isolate/context
}
