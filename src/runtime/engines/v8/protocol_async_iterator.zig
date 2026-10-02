//! The engine protocol's asynchronous iterator objects (design section 4.7):
//! WebIDL's default asynchronous iterator object (3.7.10.1) and its
//! asynchronous iterator prototype object (3.7.10.2), as V8 implements them,
//! over the host's steps - "get the next iteration result" and "asynchronous
//! iterator return".
//!
//! The prototype object is made per iterator - the protocol names no
//! interface, so there is no per-interface one to share - with next (and
//! return, when the host has one) as native closures (Function::New, not a
//! template per object), and %AsyncIteratorPrototype% as its [[Prototype]],
//! so the object is its own @@asyncIterator. Deviations, from not knowing the
//! interface: the prototype is not shared between iterators of one
//! interface, and has no class string ("<interface> AsyncIterator").
//!
//! The iterator's internal values - its ongoing promise and is finished -
//! live in a JS array the closures hold as their [[data]], with the host's
//! steps and data as Externals and the object itself (for next's and
//! return's "is this a default asynchronous iterator object" check): the
//! engine's garbage collector frees them with the iterator, and a pending
//! reaction keeps them alive as long as it needs them. `finalize`, when the
//! host gives one, runs when the object is collected.

const std = @import("std");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Owned = engine.Owned;
const Error = engine.Error;
const Here = support.Here;

/// The slots of an iterator's state array.
const Slot = enum(u32) {
    /// External: *const engine.AsyncIteratorSteps.
    steps,
    /// External: the host's data.
    data,
    /// Its ongoing promise, or undefined for null.
    ongoing,
    /// Its is finished, a boolean.
    finished,
    /// The default asynchronous iterator object itself.
    object,
};
const slot_count = @typeInfo(Slot).@"enum".fields.len;

fn slotGet(at: anytype, state: *ffi.Value, slot: Slot) Error!*ffi.Value {
    return ffi.v8_Array_Get(at.context(), @ptrCast(state), @intFromEnum(slot)) orelse error.OperationFailed;
}

fn slotSet(at: anytype, state: *ffi.Value, slot: Slot, value: *ffi.Value) Error!void {
    if (!ffi.v8_Array_Set(@ptrCast(state), at.context(), @intFromEnum(slot), value)) return error.OperationFailed;
}

fn slotSetBoolean(at: anytype, state: *ffi.Value, slot: Slot, value: bool) Error!void {
    const boolean = ffi.v8_Boolean_New(at.isolate, value) orelse return error.OperationFailed;
    defer ffi.v8_Value_Dispose(boolean);
    return slotSet(at, state, slot, boolean);
}

fn slotSetUndefined(at: anytype, state: *ffi.Value, slot: Slot) Error!void {
    const undefined_value = ffi.v8_Undefined(at.isolate) orelse return error.OperationFailed;
    defer ffi.v8_Value_Dispose(undefined_value);
    return slotSet(at, state, slot, undefined_value);
}

fn slotBoolean(at: anytype, state: *ffi.Value, slot: Slot) Error!bool {
    const value = try slotGet(at, state, slot);
    defer ffi.v8_Global_Dispose(value);
    return support.toBoolean(at, value);
}

fn slotPointer(at: anytype, state: *ffi.Value, slot: Slot) Error!?*anyopaque {
    const external = try slotGet(at, state, slot);
    defer ffi.v8_Global_Dispose(external);
    return ffi.v8_External_Value(@ptrCast(external));
}

fn stepsOf(at: anytype, state: *ffi.Value) Error!*const engine.AsyncIteratorSteps {
    const pointer = (try slotPointer(at, state, .steps)) orelse return error.OperationFailed;
    return @ptrCast(@alignCast(pointer));
}

/// What `finalize` needs once the object is collected.
const Finalizer = struct {
    steps: *const engine.AsyncIteratorSteps,
    data: ?*anyopaque,
    /// The weak Global the collection resets; disposed here.
    handle: *ffi.Value,

    const allocator = std.heap.c_allocator;

    /// V8's second pass, after the collection (v8_Global_SetWeakFinalizer):
    /// `finalize` may touch the engine.
    fn collected(raw: ?*anyopaque, _: usize) callconv(.c) void {
        const self: *Finalizer = @ptrCast(@alignCast(raw.?));
        defer allocator.destroy(self);
        // The wrapper reset the handle before calling; its Global is ours.
        ffi.v8_Global_Dispose(self.handle);
        self.steps.finalize.?(self.data);
    }
};

/// A WebIDL default asynchronous iterator object over `steps` and `data`, in
/// `realm`. OWNED.
pub fn createAsyncIterator(realm: Context, steps: *const engine.AsyncIteratorSteps, data: ?*anyopaque) Error!Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    const context = entered.context();
    const isolate = entered.isolate;

    // The asynchronous iterator prototype object: its [[Prototype]] is
    // %AsyncIteratorPrototype%.
    const async_iterator_prototype = try support.asyncIteratorPrototype(entered);
    defer ffi.v8_Global_Dispose(async_iterator_prototype);
    const prototype: *ffi.Value = @ptrCast(ffi.v8_Object_NewInContext(context) orelse return error.OperationFailed);
    defer ffi.v8_Global_Dispose(prototype);
    if (!ffi.v8_Object_SetPrototypeV2(@ptrCast(prototype), context, async_iterator_prototype)) return error.OperationFailed;

    // The default asynchronous iterator object: its [[Prototype]] is that
    // prototype object.
    const object: *ffi.Value = @ptrCast(ffi.v8_Object_NewInContext(context) orelse return error.OperationFailed);
    errdefer ffi.v8_Global_Dispose(object);
    if (!ffi.v8_Object_SetPrototypeV2(@ptrCast(object), context, prototype)) return error.OperationFailed;

    // Its internal values: target and kind are the host's (its data); its
    // ongoing promise is null, its is finished false.
    const state: *ffi.Value = @ptrCast(ffi.v8_Array_NewInContext(context, slot_count) orelse return error.OperationFailed);
    defer ffi.v8_Global_Dispose(state);
    const steps_external: *ffi.Value = @ptrCast(ffi.v8_External_New(isolate, @constCast(steps)) orelse return error.OperationFailed);
    defer ffi.v8_Global_Dispose(steps_external);
    try slotSet(entered, state, .steps, steps_external);
    const data_external: *ffi.Value = @ptrCast(ffi.v8_External_New(isolate, data) orelse return error.OperationFailed);
    defer ffi.v8_Global_Dispose(data_external);
    try slotSet(entered, state, .data, data_external);
    try slotSetUndefined(entered, state, .ongoing);
    try slotSetBoolean(entered, state, .finished, false);
    try slotSet(entered, state, .object, object);

    // A `next` data property { [[Writable]]: true, [[Enumerable]]: true,
    // [[Configurable]]: true } whose value is a built-in function object.
    try defineMethod(entered, prototype, "next", nextMethod, state, 0);
    // If an asynchronous iterator return algorithm is defined, a `return`
    // one, taking one argument `value`.
    if (steps.@"return" != null) try defineMethod(entered, prototype, "return", returnMethod, state, 1);

    if (steps.finalize != null) {
        const handle = ffi.v8_Global_Clone(object) orelse return error.OperationFailed;
        const finalizer = Finalizer.allocator.create(Finalizer) catch {
            ffi.v8_Global_Dispose(handle);
            return error.OutOfMemory;
        };
        finalizer.* = .{ .steps = steps, .data = data, .handle = handle };
        ffi.v8_Global_SetWeakFinalizer(handle, finalizer, null, Finalizer.collected);
    }
    return support.owned(object);
}

fn defineMethod(at: anytype, prototype: *ffi.Value, name: []const u8, steps: ffi.FunctionCallback, state: *ffi.Value, length: c_int) Error!void {
    const method = try support.newClosure(at, steps, state, length);
    defer ffi.v8_Global_Dispose(method);
    const key = try support.newString(at.isolate, name);
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_CreateDataProperty(@ptrCast(prototype), at.context(), key, method)) return error.OperationFailed;
}

/// Steps 3-7 of next and of return: whether the this value is this
/// iterator's default asynchronous iterator object.
fn isThisIterator(here: Here, info: *const ffi.FunctionCallbackInfo, state: *ffi.Value) Error!bool {
    // 3. Let thisValue be the this value.
    // 4. Let object be Completion(ToObject(thisValue)) - V8 hands a native
    //    function its receiver as an object.
    const this_value: *ffi.Value = @ptrCast(ffi.FunctionCallbackInfo.v8_FunctionCallbackInfo_This(info));
    defer ffi.v8_Object_Dispose(@ptrCast(this_value));
    // 6. Not a platform object: no security check.
    // 7. If object is not a default asynchronous iterator object for
    //    interface - this one.
    const object = try slotGet(here, state, .object);
    defer ffi.v8_Global_Dispose(object);
    return ffi.v8_Value_StrictEquals(this_value, object);
}

// ----------------------------------------------------------------------------
// next (3.7.10.2)
// ----------------------------------------------------------------------------

fn nextMethod(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const here = Here.ofCall(info) orelse return;
    defer here.deinit();
    const state = support.closureData(info);
    defer ffi.v8_Global_Dispose(state);
    const promise = next(here, info, state) catch
        (support.promiseRejectedWithTypeError(here, "The asynchronous iterator failed") catch return);
    support.closureReturn(info, promise);
}

fn next(here: Here, info: *const ffi.FunctionCallbackInfo, state: *ffi.Value) Error!*ffi.Value {
    // 1. Let interface be the interface the prototype object exists for.
    // 2. Let thisValidationPromiseCapability be ! NewPromiseCapability(%Promise%).
    // 3-7. If this is not the iterator, then reject
    //      thisValidationPromiseCapability with a new TypeError, and return
    //      its promise.
    if (!try isThisIterator(here, info, state)) return support.promiseRejectedWithTypeError(here, "next() called on something that is not this asynchronous iterator");
    // 8. Let nextSteps be the following steps (nextSteps, below).
    // 9. Let ongoingPromise be object's ongoing promise.
    const ongoing = try slotGet(here, state, .ongoing);
    defer ffi.v8_Global_Dispose(ongoing);
    // 10. If ongoingPromise is not null, then:
    if (!ffi.v8_Value_IsUndefined(ongoing)) {
        // 1. Let afterOngoingPromiseCapability be ! NewPromiseCapability(%Promise%).
        // 2. Let onSettled be CreateBuiltinFunction(nextSteps, 0, "", « »).
        const on_settled = try support.newClosure(here, nextSettled, state, 0);
        defer ffi.v8_Global_Dispose(on_settled);
        // 3. Perform PerformPromiseThen(ongoingPromise, onSettled, onSettled,
        //    afterOngoingPromiseCapability).
        const after = try support.then(here, ongoing, on_settled, on_settled);
        defer ffi.v8_Global_Dispose(after);
        // 4. Set object's ongoing promise to afterOngoingPromiseCapability.[[Promise]].
        try slotSet(here, state, .ongoing, after);
    } else {
        // 11. Otherwise: set object's ongoing promise to the result of
        //     running nextSteps.
        const promise = try nextSteps(here, state);
        defer ffi.v8_Global_Dispose(promise);
        try slotSet(here, state, .ongoing, promise);
    }
    // 12. Return object's ongoing promise.
    return slotGet(here, state, .ongoing);
}

/// nextSteps (next step 8). OWNED promise.
fn nextSteps(here: Here, state: *ffi.Value) Error!*ffi.Value {
    // 1. Let nextPromiseCapability be ! NewPromiseCapability(%Promise%).
    // 2. If object's is finished is true, then:
    if (try slotBoolean(here, state, .finished)) {
        // 1. Let result be CreateIteratorResultObject(undefined, true).
        const undefined_value = ffi.v8_Undefined(here.isolate) orelse return error.OperationFailed;
        defer ffi.v8_Value_Dispose(undefined_value);
        const result = try support.iteratorResultObject(here, undefined_value, true);
        defer ffi.v8_Global_Dispose(result);
        // 2. Perform ! Call(nextPromiseCapability.[[Resolve]], undefined, « result »).
        // 3. Return nextPromiseCapability.[[Promise]].
        return support.promiseResolvedWith(here, result);
    }
    // 3. Let kind be object's kind (the host's).
    // 4. Let nextPromise be the result of getting the next iteration result
    //    with object's target and object: the host's promise for an
    //    iterator result object.
    const next_promise = try hostPromise(here, state, .next, null);
    defer ffi.v8_Global_Dispose(next_promise);
    // 5-6. Let onFulfilled be CreateBuiltinFunction(fulfillSteps, 1, "", « »).
    const on_fulfilled = try support.newClosure(here, nextFulfilled, state, 1);
    defer ffi.v8_Global_Dispose(on_fulfilled);
    // 7-8. Let onRejected be CreateBuiltinFunction(rejectSteps, 1, "", « »).
    const on_rejected = try support.newClosure(here, nextRejected, state, 1);
    defer ffi.v8_Global_Dispose(on_rejected);
    // 9. Perform PerformPromiseThen(nextPromise, onFulfilled, onRejected,
    //    nextPromiseCapability).
    // 10. Return nextPromiseCapability.[[Promise]].
    return support.then(here, next_promise, on_fulfilled, on_rejected);
}

/// onSettled (next step 10.2): nextSteps, its promise the handler's result.
fn nextSettled(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const here = Here.ofCall(info) orelse return;
    defer here.deinit();
    const state = support.closureData(info);
    defer ffi.v8_Global_Dispose(state);
    const promise = nextSteps(here, state) catch
        (support.promiseRejectedWithTypeError(here, "The asynchronous iterator failed") catch return);
    support.closureReturn(info, promise);
}

/// fulfillSteps (nextSteps step 5), given next: the host's iterator result
/// object - end of iteration when its `done` is true.
fn nextFulfilled(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const here = Here.ofCall(info) orelse return;
    defer here.deinit();
    const state = support.closureData(info);
    defer ffi.v8_Global_Dispose(state);
    const next_result = support.closureArgument(info, 0);
    defer ffi.v8_Global_Dispose(next_result);
    // What reading the host's result throws is pending: the handler throws
    // it on, and the promise rejects with it.
    const result = fulfill(here, state, next_result) catch return;
    support.closureReturn(info, result);
}

fn fulfill(here: Here, state: *ffi.Value, next_result: *ffi.Value) Error!*ffi.Value {
    // 1. Set object's ongoing promise to null.
    try slotSetUndefined(here, state, .ongoing);
    if (!ffi.v8_Value_IsObject(next_result)) return support.throwTypeError(here, "The asynchronous iterator's next result is not an object");
    const done_value = try support.get(here, next_result, "done");
    const done = support.toBoolean(here, done_value);
    ffi.v8_Global_Dispose(done_value);
    // 2. If next is end of iteration, then:
    if (done) {
        // 1. Set object's is finished to true.
        try slotSetBoolean(here, state, .finished, true);
        // 2. Return CreateIteratorResultObject(undefined, true).
        const undefined_value = ffi.v8_Undefined(here.isolate) orelse return error.OperationFailed;
        defer ffi.v8_Value_Dispose(undefined_value);
        return support.iteratorResultObject(here, undefined_value, true);
    }
    // 4. Otherwise (a value asynchronously iterable declaration):
    //    3. Let value be next, converted to a JavaScript value.
    //    4. Return CreateIteratorResultObject(value, false).
    const value = try support.get(here, next_result, "value");
    defer ffi.v8_Global_Dispose(value);
    return support.iteratorResultObject(here, value, false);
}

/// rejectSteps (nextSteps step 7), given reason.
fn nextRejected(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const here = Here.ofCall(info) orelse return;
    defer here.deinit();
    const state = support.closureData(info);
    defer ffi.v8_Global_Dispose(state);
    // 1. Set object's ongoing promise to null.
    slotSetUndefined(here, state, .ongoing) catch {};
    // 2. Set object's is finished to true.
    slotSetBoolean(here, state, .finished, true) catch {};
    // 3. Throw reason.
    support.closureThrow(here.isolate, support.closureArgument(info, 0));
}

// ----------------------------------------------------------------------------
// return (3.7.10.2)
// ----------------------------------------------------------------------------

fn returnMethod(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const here = Here.ofCall(info) orelse return;
    defer here.deinit();
    const state = support.closureData(info);
    defer ffi.v8_Global_Dispose(state);
    const value = support.closureArgument(info, 0);
    defer ffi.v8_Global_Dispose(value);
    const promise = returnPromise(here, info, state, value) catch
        (support.promiseRejectedWithTypeError(here, "The asynchronous iterator failed") catch return);
    support.closureReturn(info, promise);
}

fn returnPromise(here: Here, info: *const ffi.FunctionCallbackInfo, state: *ffi.Value, value: *ffi.Value) Error!*ffi.Value {
    // 1. Let interface be the interface the prototype object exists for.
    // 2. Let returnPromiseCapability be ! NewPromiseCapability(%Promise%).
    // 3-7. If this is not the iterator, reject it with a new TypeError and
    //      return its promise.
    if (!try isThisIterator(here, info, state)) return support.promiseRejectedWithTypeError(here, "return() called on something that is not this asynchronous iterator");
    // 8. Let returnSteps be the following steps (returnSteps, below).
    // 9. Let ongoingPromise be object's ongoing promise.
    const ongoing = try slotGet(here, state, .ongoing);
    defer ffi.v8_Global_Dispose(ongoing);
    // 10. If ongoingPromise is not null, then:
    if (!ffi.v8_Value_IsUndefined(ongoing)) {
        // 1. Let afterOngoingPromiseCapability be ! NewPromiseCapability(%Promise%).
        // 2. Let onSettled be CreateBuiltinFunction(returnSteps, 0, "", « »):
        //    its [[data]] carries the state and value.
        const captured: *ffi.Value = @ptrCast(ffi.v8_Array_NewInContext(here.context(), 2) orelse return error.OperationFailed);
        defer ffi.v8_Global_Dispose(captured);
        if (!ffi.v8_Array_Set(@ptrCast(captured), here.context(), 0, state)) return error.OperationFailed;
        if (!ffi.v8_Array_Set(@ptrCast(captured), here.context(), 1, value)) return error.OperationFailed;
        const on_settled = try support.newClosure(here, returnSettled, captured, 0);
        defer ffi.v8_Global_Dispose(on_settled);
        // 3. Perform PerformPromiseThen(ongoingPromise, onSettled, onSettled,
        //    afterOngoingPromiseCapability).
        const after = try support.then(here, ongoing, on_settled, on_settled);
        defer ffi.v8_Global_Dispose(after);
        // 4. Set object's ongoing promise to afterOngoingPromiseCapability.[[Promise]].
        try slotSet(here, state, .ongoing, after);
    } else {
        // 11. Otherwise: set object's ongoing promise to the result of
        //     running returnSteps.
        const promise = try returnSteps(here, state, value);
        defer ffi.v8_Global_Dispose(promise);
        try slotSet(here, state, .ongoing, promise);
    }
    // 12. Let fulfillSteps be: return CreateIteratorResultObject(value, true).
    // 13. Let onFulfilled be CreateBuiltinFunction(fulfillSteps, 1, "", « »).
    const on_fulfilled = try support.newClosure(here, returnFulfilled, value, 1);
    defer ffi.v8_Global_Dispose(on_fulfilled);
    // 14. Perform PerformPromiseThen(object's ongoing promise, onFulfilled,
    //     undefined, returnPromiseCapability).
    const ongoing_now = try slotGet(here, state, .ongoing);
    defer ffi.v8_Global_Dispose(ongoing_now);
    // 15. Return returnPromiseCapability.[[Promise]].
    return support.then(here, ongoing_now, on_fulfilled, null);
}

/// returnSteps (return step 8). OWNED promise.
fn returnSteps(here: Here, state: *ffi.Value, value: *ffi.Value) Error!*ffi.Value {
    // 1. Let returnPromiseCapability be ! NewPromiseCapability(%Promise%).
    // 2. If object's is finished is true, then:
    if (try slotBoolean(here, state, .finished)) {
        // 1. Let result be CreateIteratorResultObject(value, true).
        const result = try support.iteratorResultObject(here, value, true);
        defer ffi.v8_Global_Dispose(result);
        // 2. Perform ! Call(returnPromiseCapability.[[Resolve]], undefined, « result »).
        // 3. Return returnPromiseCapability.[[Promise]].
        return support.promiseResolvedWith(here, result);
    }
    // 3. Set object's is finished to true.
    try slotSetBoolean(here, state, .finished, true);
    // 4. Return the result of running the asynchronous iterator return
    //    algorithm, given object's target, object, and value: the host's.
    return hostPromise(here, state, .@"return", value);
}

/// onSettled (return step 10.2): returnSteps with the captured value.
fn returnSettled(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const here = Here.ofCall(info) orelse return;
    defer here.deinit();
    const captured = support.closureData(info);
    defer ffi.v8_Global_Dispose(captured);
    const state = ffi.v8_Array_Get(here.context(), @ptrCast(captured), 0) orelse return;
    defer ffi.v8_Global_Dispose(state);
    const value = ffi.v8_Array_Get(here.context(), @ptrCast(captured), 1) orelse return;
    defer ffi.v8_Global_Dispose(value);
    const promise = returnSteps(here, state, value) catch
        (support.promiseRejectedWithTypeError(here, "The asynchronous iterator failed") catch return);
    support.closureReturn(info, promise);
}

/// fulfillSteps (return step 12): CreateIteratorResultObject(value, true),
/// `value` its [[data]].
fn returnFulfilled(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const here = Here.ofCall(info) orelse return;
    defer here.deinit();
    const value = support.closureData(info);
    defer ffi.v8_Global_Dispose(value);
    // 1. Return CreateIteratorResultObject(value, true).
    const result = support.iteratorResultObject(here, value, true) catch return;
    support.closureReturn(info, result);
}

// ----------------------------------------------------------------------------
// The host's steps
// ----------------------------------------------------------------------------

/// The host's "get the next iteration result" or "asynchronous iterator
/// return" - a promise, whatever the host answered: a value that is not a
/// promise resolves one, and what the host threw or failed with rejects one.
/// OWNED.
fn hostPromise(here: Here, state: *ffi.Value, which: enum { next, @"return" }, value: ?*ffi.Value) Error!*ffi.Value {
    const steps = try stepsOf(here, state);
    const data = try slotPointer(here, state, .data);
    var body: struct {
        steps: *const engine.AsyncIteratorSteps,
        data: ?*anyopaque,
        which: @TypeOf(which),
        value: ?*ffi.Value,
        result: Error!Owned = error.OperationFailed,
        pub fn run(self: *@This()) void {
            self.result = switch (self.which) {
                .next => self.steps.next(self.data),
                .@"return" => self.steps.@"return".?(self.data, support.borrowed(self.value.?)),
            };
        }
    } = .{ .steps = steps, .data = data, .which = which, .value = value };
    var thrown: ?*ffi.Value = null;
    if (support.catching(here.isolate, &body, &thrown)) {
        const reason = thrown orelse return support.promiseRejectedWithTypeError(here, "The asynchronous iterator's steps threw");
        defer ffi.v8_Global_Dispose(reason);
        if (body.result) |owned| owned.release() else |_| {}
        return support.promiseRejectedWith(here, reason);
    }
    const owned = body.result catch return support.promiseRejectedWithTypeError(here, "The asynchronous iterator's steps failed");
    defer owned.release();
    const answer = try support.ownGlobal(here, owned.value);
    defer ffi.v8_Global_Dispose(answer);
    if (ffi.v8_Value_IsPromise(answer)) return ffi.v8_Global_Clone(answer) orelse error.OperationFailed;
    return support.promiseResolvedWith(here, answer);
}
