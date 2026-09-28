//! The engine protocol's promise reactions (design section 4.9): WebIDL "react
//! to" a promise, as V8 implements it.
//!
//! v8_Promise_React is PerformPromiseThen(promise, onFulfilled, onRejected,
//! newCapability) with both reactions calling back into Zig - functions made
//! with Function::New, not a template per reaction, which a context would
//! keep for its lifetime. The promise it derives is marked handled: "react
//! to" returns nothing here, so nothing observes it (WebIDL allows not
//! creating it at all).
//!
//! A reaction's record is freed when the promise settles. One that never
//! settles keeps its record - two pointers here, two in the wrapper - until
//! the process ends: the FFI has no hook for the reaction functions being
//! collected.

const std = @import("std");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Error = engine.Error;

const Reaction = struct {
    steps: *const engine.PromiseReactionSteps,
    data: ?*anyopaque,

    const allocator = std.heap.c_allocator;

    /// Exactly once, when the promise settles: `value` is a new Global this
    /// owns.
    fn settled(raw: ?*anyopaque, value: ?*ffi.Value, rejected: bool) callconv(.c) void {
        const self: *Reaction = @ptrCast(@alignCast(raw.?));
        const steps = self.steps;
        const data = self.data;
        allocator.destroy(self);
        defer if (value) |v| ffi.v8_Global_Dispose(v);
        const argument: JSValue = if (value) |v| support.borrowed(v) else JSValue.jsUndefined;
        if (rejected) {
            // onRejectedSteps: 1. Let reason be R converted to `any`.
            // 2. If there is a set of steps to be run if the promise was
            //    rejected, then let result be the result of performing them,
            //    given reason. Otherwise, let result be a promise rejected with
            //    reason - the derived promise's, which nothing observes.
            if (steps.rejected) |rejected_steps| rejected_steps(data, argument);
        } else {
            // onFulfilledSteps: 1. Let value be V converted to T (the steps'
            //    own conversion). 2. If there is a set of steps to be run if
            //    the promise was fulfilled, then let result be the result of
            //    performing them, given value. Otherwise, let result be value.
            if (steps.fulfilled) |fulfilled_steps| fulfilled_steps(data, argument);
        }
        // 3. Return result, converted to a JavaScript value: the derived
        //    promise's value, which nothing observes.
    }
};

/// WebIDL "react to" `promise`: `steps` upon fulfillment and upon rejection,
/// in `realm`. `steps` and `data` are BORROWED until the promise settles.
pub fn reactToPromise(realm: Context, promise: JSValue, steps: *const engine.PromiseReactionSteps, data: ?*anyopaque) Error!void {
    const entered = try support.enter(realm);
    defer entered.leave();
    const target = support.handleOf(promise) orelse return error.TypeError;
    if (!ffi.v8_Value_IsPromise(target)) return error.TypeError;

    const reaction = Reaction.allocator.create(Reaction) catch return error.OutOfMemory;
    reaction.* = .{ .steps = steps, .data = data };
    // 1-4. onFulfilled and onRejected: CreateBuiltinFunction over the steps.
    // 5-6. Let newCapability be ? NewPromiseCapability(%Promise% of the
    //      promise's realm) - V8's derived promise.
    // 7. Perform PerformPromiseThen(promise.[[Promise]], onFulfilled,
    //    onRejected, newCapability).
    if (!ffi.v8_Promise_React(entered.context(), target, Reaction.settled, reaction)) {
        Reaction.allocator.destroy(reaction);
        return error.OperationFailed;
    }
    // 8. Return newCapability: not observed (see above).
}
