//! DOM § 6 "filter", steps 6 and 8, shared by NodeIterator and TreeWalker:
//! call the traverser's NodeFilter and convert what it answers.
//!
//! The filter is a WebIDL callback interface: a function, or an object whose
//! `acceptNode` is looked up when it is called. Either way the call goes
//! through `CallbackWrapper.callOperationCatching`, which performs that lookup
//! and returns what was thrown rather than dropping it - step 8 rethrows it.
//! The active flag (steps 1, 5 and 7) stays with each traverser.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");

/// Invoke `filter` with « node » and return its answer as an unsigned short,
/// or `error.ExceptionPending` once the exception it threw has been rethrown.
pub fn call(filter: *runtime.CallbackWrapper, node: *runtime.Instance) !u16 {
    const ffi = v8.ffi;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return error.InvalidStateError;
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.OutOfMemory;
    defer ffi.v8_HandleScope_Dispose(scope);
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.InvalidStateError;
    defer ffi.v8_Context_Dispose(context);

    // The node's wrapper - the wrapper cache's own Global, borrowed - lent to
    // the call as a Local, which is what the call's arguments are.
    const node_global = v8.conversions.instanceToV8(isolate, node);
    const node_local = ffi.v8_Global_Get(isolate, node_global) orelse return error.InvalidStateError;

    const wrapper: *v8.CallbackWrapper = @ptrCast(@alignCast(filter.engine_handle));
    switch (wrapper.callOperationCatching(context, "acceptNode", null, &.{@ptrCast(node_local)})) {
        // Step 8: "If an exception was thrown, re-throw the exception."
        .thrown => |exception| {
            if (exception) |e| {
                ffi.v8_Isolate_ThrowException(isolate, e);
                ffi.v8_Global_Dispose(e);
            }
            return error.ExceptionPending;
        },
        // The callback's return type is `unsigned short`: ToNumber, then
        // ConvertToInt. ToNumber throws for a Symbol or a BigInt.
        .normal => |result| {
            const value = result orelse return 0;
            defer ffi.v8_Global_Dispose(value);
            if (ffi.v8_Value_IsSymbol(value) or ffi.v8_Value_IsBigInt(value)) {
                v8.conversions.throwTypeError(isolate, "Cannot convert a Symbol or BigInt to a number");
                return error.ExceptionPending;
            }
            return v8.conversions.convertToInt(u16, ffi.v8_Value_NumberValue(value, context));
        },
    }
}

/// The filter as script sees it: `nodeIterator.filter`, `treeWalker.filter`.
pub fn fromStored(stored: ?*anyopaque) ?*runtime.CallbackWrapper {
    const raw = stored orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// Release a stored filter: the engine's wrapper (and the Global it holds),
/// then the runtime wrapper, which the conversion allocated.
pub fn release(stored: ?*anyopaque) void {
    const filter = fromStored(stored) orelse return;
    filter.deinit();
    filter.allocator.destroy(filter);
}
