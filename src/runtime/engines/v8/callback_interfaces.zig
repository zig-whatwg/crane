//! Callbacks an impl holds and calls - the V8 side of the Engine table's
//! callUserObjectOperation and takeCallbackFunction (AGENTS.md, "The engine
//! boundary").
//!
//! A callback interface value (a NodeFilter, an XPathNSResolver) reaches an
//! impl as a runtime.CallbackWrapper - this adapter's CallbackWrapper, which
//! already performs WebIDL's "call a user object's operation" lookup
//! (callOperationCatching). This file turns that into the operation's
//! contract: arguments as runtime.JSValues, exception behaviour "rethrow",
//! and the return value as an OWNED handle.

const runtime = @import("runtime");
const EngineError = runtime.EngineError;
const JSValue = runtime.JSValue;

const ffi = @import("ffi.zig");
const V8CallbackWrapper = @import("callback_wrapper.zig").CallbackWrapper;
const realm_entry = @import("realm_entry.zig");
const pointer_tag = @import("pointer_tag.zig");

/// The most arguments a callback interface operation is called with here
/// (callOperationCatching's own bound).
const max_arguments = 16;

/// WebIDL "call a user object's operation" `operation_name` on `callback`
/// with `args`, from `realm`, rethrowing what it throws.
pub fn callUserObjectOperation(
    realm: runtime.Context,
    callback: *runtime.CallbackWrapper,
    operation_name: []const u8,
    args: []const JSValue,
) EngineError!JSValue {
    if (args.len > max_arguments) return EngineError.OperationFailed;
    const entered = try realm_entry.enter(realm);
    defer entered.leave();
    const context = entered.context();

    // The call takes its arguments as Local slots: each argument's Global -
    // borrowed, or made here and released after the call - read into one.
    var values: [max_arguments]realm_entry.EngineValue = undefined;
    var made: usize = 0;
    defer for (values[0..made]) |value| value.release();
    var locals: [max_arguments]*ffi.Value = undefined;
    for (args, 0..) |arg, i| {
        values[i] = try realm_entry.EngineValue.of(entered.isolate, context, arg);
        made += 1;
        const local = ffi.v8_Global_Get(entered.isolate, values[i].ptr) orelse return EngineError.OperationFailed;
        locals[i] = @ptrCast(@alignCast(local));
    }

    const wrapper: *V8CallbackWrapper = @ptrCast(@alignCast(callback));
    switch (wrapper.callOperationCatching(context, operation_name, null, locals[0..args.len])) {
        // "rethrow": the exception is script's again, in flight.
        .thrown => |exception| {
            if (exception) |e| {
                ffi.v8_Isolate_ThrowException(entered.isolate, e);
                ffi.v8_Global_Dispose(e);
            }
            return EngineError.ExceptionPending;
        },
        .normal => |result| {
            const value = result orelse return JSValue.jsUndefined;
            return realm_entry.owned(@ptrCast(value));
        },
    }
}

/// A callback-function value as the conversion makes it - the Global it holds
/// (conversions.zig, "callback function"; a `.global_handle` tag in its low
/// bits is ignored) - taken by the impl that keeps it, as a hold of the
/// caller's own (OWNED). The value is BORROWED for the call: the binding
/// frees its Global with the rest of the value when the call returns
/// (interface.freeConvertedArg), so the function MOVES out of it into a
/// Global of the taker's (v8_Global_TakeOver - no V8 handle made, one 16 B
/// box). An impl that never takes the callback leaves the binding's Global
/// to the binding, which frees it: a stub that drops its callback keeps
/// nothing (ResizeObserver's constructor kept one per call, lane leaks7).
///
/// Taken twice, the value holds nothing the second time: undefined, nothing
/// to release. A take after the call returned reads a freed Global - every
/// impl takes during its call (lane leaks7's audit).
pub fn takeCallbackFunction(argument: *const anyopaque) JSValue {
    const untagged = pointer_tag.untagPointer(argument);
    const own = ffi.v8_Global_TakeOver(@ptrCast(@alignCast(untagged.ptr))) orelse return JSValue.jsUndefined;
    return realm_entry.owned(@ptrCast(own));
}
