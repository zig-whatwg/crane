//! Engine operations on values that cross the seam and are held there:
//! retainValue, throwValue and createFrozenArrayOfPlatformObjects, as V8
//! implements them (AGENTS.md, "The engine boundary"). The WebIDL conversions
//! of arguments an impl takes unconverted are webidl_conversions.zig.
//!
//! Code outside the adapter holds a script value as a `runtime.JSValue`. When
//! it must outlive the call that handed it over - an AbortSignal's reason, a
//! timer's callback - the engine gives it a handle of its own (`retainValue`),
//! released with the Engine table's `releaseValue`. Every function here enters
//! the realm it is given, so a caller needs no scope of its own.

const std = @import("std");
const runtime = @import("runtime");
const EngineError = runtime.EngineError;

const ffi = @import("ffi.zig");
const engine = @import("engine.zig");
const conversions = @import("conversions.zig");

/// A handle of our own for `value`, entered in `isolate`/`context`: always a
/// new Global the caller disposes. Borrowed inputs are copied, never taken.
pub fn ownHandle(isolate: *ffi.Isolate, context: *ffi.Context, value: runtime.JSValue) EngineError!*ffi.Value {
    return switch (value) {
        // Copied into a second, independently owned Global.
        .handle => ffi.v8_Global_Clone(handleOf(value).?) orelse EngineError.OperationFailed,
        // The wrapper cache owns the wrapper; the caller gets its own handle.
        .instance => |instance| blk: {
            const wrapper = conversions.instanceToV8(isolate, instance);
            break :blk ffi.v8_Global_Clone(wrapper) orelse EngineError.OperationFailed;
        },
        // Every other kind is made here, in the realm: a new Global.
        else => conversions.toV8Value(runtime.JSValue, isolate, context, value) catch EngineError.OperationFailed,
    };
}

/// The V8 value a `.handle` JSValue holds, BORROWED; null for any other kind.
///
/// The pointer is a Global<Value>* whichever way `handle_scope` is tagged.
/// `.local` says who owns it and how long it lives - the binding's own
/// handle for an argument, valid for the call (conversions.fromV8Value) -
/// not that it is a Local's slot: every value this FFI hands out is a
/// Global. Reading a `.local` one as a Local (v8_Value_ToGlobal,
/// v8_Value_IsFunction_Local) reinterprets the Global's address as the
/// value, which is how AbortSignal.abort({...}).throwIfAborted() came to
/// throw a number.
pub fn handleOf(value: runtime.JSValue) ?*ffi.Value {
    return switch (value) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        else => null,
    };
}

/// Engine table `retainValue`: OWNED `.handle` for any `value`.
pub fn retainValue(realm: runtime.Context, value: runtime.JSValue) EngineError!runtime.JSValue {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const held = try ownHandle(entered.isolate, entered.scope.context, value);
    return .{ .handle = .{ .ptr = @ptrCast(held), .needs_disposal = true, .handle_scope = .global } };
}

/// Engine table `throwValue`: `value` (borrowed) becomes the pending
/// exception of `realm`'s agent.
pub fn throwValue(realm: runtime.Context, value: runtime.JSValue) EngineError!void {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    // ThrowException takes the value, not the handle: ours goes after.
    const thrown = try ownHandle(entered.isolate, entered.scope.context, value);
    defer ffi.v8_Global_Dispose(thrown);
    ffi.v8_Isolate_ThrowException(entered.isolate, thrown);
}

/// Engine table `createFrozenArrayOfPlatformObjects`: WebIDL "create a
/// frozen array" from a list of platform objects - each item its wrapper in
/// `realm`, the array made in `realm` and frozen. OWNED `.handle`.
pub fn createFrozenArrayOfPlatformObjects(realm: runtime.Context, instances: []const *runtime.Instance) EngineError!runtime.JSValue {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const isolate = entered.isolate;
    const context = entered.scope.context;
    // 1. Let array be the result of converting the list of values to an
    // ECMAScript value - an Array of `realm`.
    const array = ffi.v8_Array_NewInContext(context, @intCast(instances.len)) orelse return EngineError.OperationFailed;
    errdefer ffi.v8_Array_Dispose(array);
    for (instances, 0..) |instance, i| {
        // Borrowed: the wrapper cache owns the wrapper; Set keeps its own.
        const wrapper = conversions.instanceToV8(isolate, instance);
        if (!ffi.v8_Array_Set(array, context, @intCast(i), wrapper)) return EngineError.OperationFailed;
    }
    // 2. Perform ! SetIntegrityLevel(array, "frozen").
    if (!ffi.v8_Object_Freeze(@ptrCast(array), context)) return EngineError.OperationFailed;
    // 3. Return array.
    return .{ .handle = .{ .ptr = @ptrCast(array), .needs_disposal = true, .handle_scope = .global } };
}
