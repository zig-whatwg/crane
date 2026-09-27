//! The engine protocol's iteration and sequence operations (design sections
//! 4.6 and 4.7), as V8 implements them: ECMAScript's Iterator Records
//! (GetIterator, IteratorNext, IteratorComplete / IteratorValue, the
//! iterator's `return`), and WebIDL's conversions over them - "create a
//! sequence from an iterable" item by item (`iterate`), sequence<any>, a
//! sequence of string pairs - and "create a frozen array".
//!
//! Each enters the realm it is given. What script throws is left pending
//! (ExceptionPending); "throw a TypeError" with nothing thrown is TypeError,
//! for the caller to throw.
//!
//! An async iterator over a sync iterable is ECMAScript's
//! CreateAsyncFromSyncIterator: the record keeps the sync iterator, and its
//! next and return run %AsyncFromSyncIteratorPrototype%'s steps directly -
//! the async-from-sync object is never exposed to script, so it is not made.
//!
//! GetIterator of a primitive reads its method through ToObject (GetMethod's
//! GetV), so a string iterates its code points.

const std = @import("std");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");
const webidl_conversions = @import("webidl_conversions.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Owned = engine.Owned;
const Error = engine.Error;
const Entered = support.Entered;
const Allocator = std.mem.Allocator;

// ============================================================================
// Iterator Records
// ============================================================================

/// An ECMAScript Iterator Record. `engine.IteratorRecord` is this, opaque.
const Record = struct {
    /// [[Iterator]]. OWNED.
    iterator: *ffi.Value,
    /// [[NextMethod]]. OWNED.
    next_method: *ffi.Value,
    /// [[Done]].
    done: bool,
    /// Whether [[NextMethod]] answers with promises (an async iterator): its
    /// results are awaited by the caller before they are read.
    kind: engine.IteratorKind,
    /// An async iterator over a sync one (CreateAsyncFromSyncIterator):
    /// [[Iterator]] and [[NextMethod]] are the sync iterator's, and next and
    /// return are %AsyncFromSyncIteratorPrototype%'s.
    from_sync: bool = false,
    allocator: Allocator,

    fn of(record: *engine.IteratorRecord) *Record {
        return @ptrCast(@alignCast(record));
    }

    fn release(self: *Record) void {
        ffi.v8_Global_Dispose(self.iterator);
        ffi.v8_Global_Dispose(self.next_method);
        self.allocator.destroy(self);
    }
};

/// ECMAScript GetIteratorFromMethod(obj, method). OWNED record.
fn getIteratorFromMethod(entered: Entered, object: *ffi.Value, method: *ffi.Value, kind: engine.IteratorKind, allocator: Allocator) Error!*Record {
    // 1. Let iterator be ? Call(method, obj).
    const iterator = try support.call(entered, method, object, &.{});
    errdefer ffi.v8_Global_Dispose(iterator);
    // 2. If iterator is not an Object, throw a TypeError exception.
    if (!ffi.v8_Value_IsObject(iterator)) return error.TypeError;
    // 3. Let nextMethod be ? Get(iterator, "next").
    const next_method = try support.get(entered, iterator, "next");
    errdefer ffi.v8_Global_Dispose(next_method);
    // 4. Let iteratorRecord be the Iterator Record { [[Iterator]]: iterator,
    //    [[NextMethod]]: nextMethod, [[Done]]: false }.
    const record = allocator.create(Record) catch return error.OutOfMemory;
    record.* = .{ .iterator = iterator, .next_method = next_method, .done = false, .kind = kind, .allocator = allocator };
    // 5. Return iteratorRecord.
    return record;
}

/// ECMAScript IteratorNext(iteratorRecord): the result object. For an async
/// iterator, the result as [[NextMethod]] returned it (a promise), for the
/// caller to await and then check. OWNED.
fn iteratorNextValue(entered: Entered, record: *Record) Error!*ffi.Value {
    // 1. Let result be Completion(Call(iteratorRecord.[[NextMethod]],
    //    iteratorRecord.[[Iterator]])). Call throws a TypeError for a
    //    [[NextMethod]] that is not callable.
    if (!ffi.v8_Value_IsFunction(record.next_method)) {
        record.done = true;
        return error.TypeError;
    }
    // 3. If result is a throw completion, then set iteratorRecord.[[Done]]
    //    to true, and return ? result.
    const result = support.call(entered, record.next_method, record.iterator, &.{}) catch |err| {
        record.done = true;
        return err;
    };
    // 4. Set result to ! result.
    // 5. If result is not an Object, then set iteratorRecord.[[Done]] to
    //    true and throw a TypeError exception.
    if (record.kind == .sync and !ffi.v8_Value_IsObject(result)) {
        ffi.v8_Global_Dispose(result);
        record.done = true;
        return error.TypeError;
    }
    // 6. Return result.
    return result;
}

/// ECMAScript IteratorStepValue(iteratorRecord): the next value (OWNED), or
/// null for DONE.
fn stepValue(entered: Entered, record: *Record) Error!?*ffi.Value {
    // IteratorStep(iteratorRecord):
    // 1. Let result be ? IteratorNext(iteratorRecord).
    const result = try iteratorNextValue(entered, record);
    defer ffi.v8_Global_Dispose(result);
    // 2. Let done be Completion(IteratorComplete(result)):
    //    ToBoolean(? Get(iterResult, "done")).
    // 3. If done is a throw completion, set iteratorRecord.[[Done]] to true.
    // 4. Set done to ? done.
    const done_value = support.get(entered, result, "done") catch |err| {
        record.done = true;
        return err;
    };
    const done = support.toBoolean(entered, done_value);
    ffi.v8_Global_Dispose(done_value);
    // 5. If done is true, then set iteratorRecord.[[Done]] to true, and
    //    return DONE.
    if (done) {
        record.done = true;
        return null;
    }
    // IteratorStepValue:
    // 3. Let value be Completion(IteratorValue(result)): ? Get(iterResult,
    //    "value").
    // 4. If value is a throw completion, set iteratorRecord.[[Done]] to true.
    // 5. Return ? value.
    return support.get(entered, result, "value") catch |err| {
        record.done = true;
        return err;
    };
}

/// ECMAScript GetIterator(obj, kind). OWNED: releaseIteratorRecord.
pub fn getIterator(realm: Context, value: JSValue, kind: engine.IteratorKind) Error!*engine.IteratorRecord {
    const entered = try support.enter(realm);
    defer entered.leave();
    const object = try support.ownGlobal(entered, value);
    defer ffi.v8_Global_Dispose(object);
    // GetMethod(obj, P)'s GetV(obj, P): 1. Let O be ? ToObject(V) - a
    // primitive's methods are its wrapper object's (undefined and null are
    // ToObject's TypeError); the method is then called with `obj` itself.
    const methods_of: *ffi.Value = if (ffi.v8_Value_IsObject(object))
        object
    else
        ffi.v8_Value_ToObject(entered.context(), object) orelse return error.TypeError;
    defer if (methods_of != object) ffi.v8_Global_Dispose(methods_of);

    const method: ?*ffi.Value = switch (kind) {
        // 1. If kind is async, then
        .async => blk: {
            // a. Let method be ? GetMethod(obj, %Symbol.asyncIterator%).
            if (try support.getSymbolMethod(entered, methods_of, .async_iterator)) |async_method| break :blk async_method;
            // b. If method is undefined, then
            //    i. Let syncMethod be ? GetMethod(obj, %Symbol.iterator%).
            //    ii. If syncMethod is undefined, throw a TypeError exception.
            const sync_method = (try support.getSymbolMethod(entered, methods_of, .iterator)) orelse return error.TypeError;
            defer ffi.v8_Global_Dispose(sync_method);
            //    iii. Let syncIteratorRecord be ? GetIteratorFromMethod(obj,
            //         syncMethod).
            const record = try getIteratorFromMethod(entered, object, sync_method, .sync, realm.allocator);
            //    iv. Return CreateAsyncFromSyncIterator(syncIteratorRecord):
            //        the record, read through %AsyncFromSyncIteratorPrototype%.
            record.kind = .async;
            record.from_sync = true;
            return @ptrCast(record);
        },
        // 2. Otherwise, let method be ? GetMethod(obj, %Symbol.iterator%).
        .sync => try support.getSymbolMethod(entered, methods_of, .iterator),
    };
    // 3. If method is undefined, throw a TypeError exception.
    const iterator_method = method orelse return error.TypeError;
    defer ffi.v8_Global_Dispose(iterator_method);
    // 4. Return ? GetIteratorFromMethod(obj, method).
    const record = try getIteratorFromMethod(entered, object, iterator_method, kind, realm.allocator);
    return @ptrCast(record);
}

/// ECMAScript IteratorNext(iteratorRecord). OWNED.
pub fn iteratorNext(realm: Context, record: *engine.IteratorRecord) Error!Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    const self = Record.of(record);
    if (self.from_sync) return support.owned(try asyncFromSyncNext(entered, self));
    return support.owned(try iteratorNextValue(entered, self));
}

/// The iterator's `return` called with `value` - IteratorClose's and
/// AsyncIteratorClose's call, and Streams' cancel steps for an iterable:
/// its result (OWNED), or null when the iterator has no `return`.
pub fn iteratorReturn(realm: Context, record: *engine.IteratorRecord, value: JSValue) Error!?Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    const self = Record.of(record);
    if (self.from_sync) return support.owned(try asyncFromSyncReturn(entered, self, value));
    // 1. Let iterator be iteratorRecord.[[Iterator]].
    // 2. Let returnMethod be ? GetMethod(iterator, "return").
    const return_method = try support.get(entered, self.iterator, "return");
    defer ffi.v8_Global_Dispose(return_method);
    // 3. If returnMethod is undefined, return (null).
    if (ffi.v8_Value_IsUndefined(return_method) or ffi.v8_Value_IsNull(return_method)) return null;
    if (!ffi.v8_Value_IsFunction(return_method)) return error.TypeError;
    // 4. Let innerResult be ? Call(return, iterator, « value »).
    const argument = try support.ownGlobal(entered, value);
    defer ffi.v8_Global_Dispose(argument);
    return support.owned(try support.call(entered, return_method, self.iterator, &.{argument}));
}

/// IteratorComplete(iterResult) and IteratorValue(iterResult) of `result`.
pub fn iteratorResult(realm: Context, result: JSValue) Error!engine.IteratorResult {
    const entered = try support.enter(realm);
    defer entered.leave();
    const object = try support.ownGlobal(entered, result);
    defer ffi.v8_Global_Dispose(object);
    // An iterator result must be an Object (IteratorNext step 5, and the
    // awaited result of an async iterator's next).
    if (!ffi.v8_Value_IsObject(object)) return error.TypeError;
    // IteratorComplete: 1. Return ToBoolean(? Get(iterResult, "done")).
    const done_value = try support.get(entered, object, "done");
    const done = support.toBoolean(entered, done_value);
    ffi.v8_Global_Dispose(done_value);
    // IteratorValue: 1. Return ? Get(iterResult, "value").
    const value = try support.get(entered, object, "value");
    return .{ .done = done, .value = support.owned(value) };
}

// ============================================================================
// CreateAsyncFromSyncIterator (ECMAScript 27.1.6)
// ============================================================================

/// IfAbruptRejectPromise: a promise rejected with what was thrown. Takes it.
fn rejectWith(at: anytype, thrown: *ffi.Value) Error!*ffi.Value {
    defer ffi.v8_Global_Dispose(thrown);
    return support.promiseRejectedWith(at, thrown);
}

/// %AsyncFromSyncIteratorPrototype%.next(), with no value. OWNED promise.
fn asyncFromSyncNext(at: anytype, record: *Record) Error!*ffi.Value {
    // 1-2. Let O be the this value; its [[SyncIteratorRecord]]: `record`.
    // 3. Let promiseCapability be ! NewPromiseCapability(%Promise%) - made as
    //    it settles, below; NewPromiseCapability of %Promise% observes nothing.
    // 4. Let syncIteratorRecord be O.[[SyncIteratorRecord]].
    // 5. Let result be Completion(IteratorNext(syncIteratorRecord)).
    const result = switch (try syncIteratorNextCaught(at, record)) {
        // 6. IfAbruptRejectPromise(result, promiseCapability).
        .thrown => |thrown| return rejectWith(at, thrown),
        .normal => |value| value,
    };
    defer ffi.v8_Global_Dispose(result);
    // 7. Return AsyncFromSyncIteratorContinuation(result, promiseCapability,
    //    syncIteratorRecord, true).
    return asyncFromSyncContinuation(at, record, result, true);
}

/// %AsyncFromSyncIteratorPrototype%.return(value). OWNED promise.
fn asyncFromSyncReturn(at: anytype, record: *Record, value: JSValue) Error!*ffi.Value {
    const argument = try support.ownGlobal(at, value);
    defer ffi.v8_Global_Dispose(argument);
    // 5. Let syncIterator be syncIteratorRecord.[[Iterator]].
    // 6. Let return be Completion(GetMethod(syncIterator, "return")).
    const return_method = switch (try support.getCaught(at, record.iterator, "return")) {
        // 7. IfAbruptRejectPromise(return, promiseCapability).
        .thrown => |thrown| return rejectWith(at, thrown),
        .normal => |method| method,
    };
    defer ffi.v8_Global_Dispose(return_method);
    // 8. If return is undefined, then
    if (ffi.v8_Value_IsUndefined(return_method) or ffi.v8_Value_IsNull(return_method)) {
        // a. Let iteratorResult be CreateIteratorResultObject(value, true).
        const iterator_result = try support.iteratorResultObject(at, argument, true);
        defer ffi.v8_Global_Dispose(iterator_result);
        // b. Perform ! Call(promiseCapability.[[Resolve]], undefined,
        //    « iteratorResult »).
        // c. Return promiseCapability.[[Promise]].
        return support.promiseResolvedWith(at, iterator_result);
    }
    // (GetMethod: a value that is not callable is a TypeError.)
    // 9. If value is present, then let result be Completion(Call(return,
    //    syncIterator, « value »)).
    const result = switch (try support.callCaught(at, return_method, record.iterator, &.{argument})) {
        // 10. IfAbruptRejectPromise(result, promiseCapability).
        .thrown => |thrown| return rejectWith(at, thrown),
        .normal => |r| r,
    };
    defer ffi.v8_Global_Dispose(result);
    // 11. If result is not an Object, then reject promiseCapability with a
    //     new TypeError, and return its promise.
    if (!ffi.v8_Value_IsObject(result)) return support.promiseRejectedWithTypeError(at, "The iterator's return did not answer an object");
    // 12. Return AsyncFromSyncIteratorContinuation(result, promiseCapability,
    //     syncIteratorRecord, false).
    return asyncFromSyncContinuation(at, record, result, false);
}

/// IteratorNext(syncIteratorRecord), its Completion.
fn syncIteratorNextCaught(at: anytype, record: *Record) Error!support.Caught {
    // 1. Let result be Completion(Call(iteratorRecord.[[NextMethod]],
    //    iteratorRecord.[[Iterator]])).
    const result = try support.callCaught(at, record.next_method, record.iterator, &.{});
    switch (result) {
        // 3. If result is a throw completion, then set [[Done]] to true, and
        //    return ? result.
        .thrown => {
            record.done = true;
            return result;
        },
        .normal => |value| {
            // 5. If result is not an Object, then set [[Done]] to true, and
            //    throw a TypeError exception.
            if (!ffi.v8_Value_IsObject(value)) {
                ffi.v8_Global_Dispose(value);
                record.done = true;
                return .{ .thrown = try support.newTypeError(at.isolate, at.context(), "The iterator's next did not answer an object") };
            }
            // 6. Return result.
            return result;
        },
    }
}

/// AsyncFromSyncIteratorContinuation(result, promiseCapability,
/// syncIteratorRecord, closeOnRejection). OWNED promise.
fn asyncFromSyncContinuation(at: anytype, record: *Record, result: *ffi.Value, close_on_rejection: bool) Error!*ffi.Value {
    // 2. Let done be Completion(IteratorComplete(result)).
    const done_value = switch (try support.getCaught(at, result, "done")) {
        // 3. IfAbruptRejectPromise(done, promiseCapability).
        .thrown => |thrown| return rejectWith(at, thrown),
        .normal => |v| v,
    };
    const done = support.toBoolean(at, done_value);
    ffi.v8_Global_Dispose(done_value);
    // 4. Let value be Completion(IteratorValue(result)).
    const value = switch (try support.getCaught(at, result, "value")) {
        // 5. IfAbruptRejectPromise(value, promiseCapability).
        .thrown => |thrown| return rejectWith(at, thrown),
        .normal => |v| v,
    };
    defer ffi.v8_Global_Dispose(value);
    // 6. Let valueWrapper be Completion(PromiseResolve(%Promise%, value)).
    const value_wrapper = switch (try support.promiseResolve(at, value)) {
        .thrown => |thrown| {
            // 7. If valueWrapper is an abrupt completion, done is false, and
            //    closeOnRejection is true, then set valueWrapper to
            //    Completion(IteratorClose(syncIteratorRecord, valueWrapper)) -
            //    which is valueWrapper again: IteratorClose returns a throw
            //    completion it is given, whatever `return` does.
            if (!done and close_on_rejection) closeQuietly(at, record.iterator);
            // 8. IfAbruptRejectPromise(valueWrapper, promiseCapability).
            return rejectWith(at, thrown);
        },
        .normal => |wrapper| wrapper,
    };
    defer ffi.v8_Global_Dispose(value_wrapper);
    // 9. Let unwrap be a new Abstract Closure with parameters (v) that
    //    captures done: return CreateIteratorResultObject(v, done).
    // 10. Let onFulfilled be CreateBuiltinFunction(unwrap, 1, "", « »).
    const done_data = ffi.v8_Boolean_New(at.isolate, done) orelse return error.OperationFailed;
    defer ffi.v8_Value_Dispose(done_data);
    const on_fulfilled = try support.newClosure(at, unwrapSteps, done_data, 1);
    defer ffi.v8_Global_Dispose(on_fulfilled);
    // 12. If done is true, or if closeOnRejection is false, then let
    //     onRejected be undefined.
    // 13. Else, let closeIterator be a new Abstract Closure with parameters
    //     (error) that captures syncIteratorRecord: return ?
    //     IteratorClose(syncIteratorRecord, ThrowCompletion(error)); and let
    //     onRejected be CreateBuiltinFunction(closeIterator, 1, "", « »).
    const on_rejected: ?*ffi.Value = if (done or !close_on_rejection) null else try support.newClosure(at, closeIteratorSteps, record.iterator, 1);
    defer if (on_rejected) |f| ffi.v8_Global_Dispose(f);
    // 14. Perform PerformPromiseThen(valueWrapper, onFulfilled, onRejected,
    //     promiseCapability).
    // 15. Return promiseCapability.[[Promise]].
    return support.then(at, value_wrapper, on_fulfilled, on_rejected);
}

/// IteratorClose(iteratorRecord, completion) for a throw completion: the
/// iterator's `return` called, and whatever it does ignored - step 5 returns
/// the throw completion it was given.
fn closeQuietly(at: anytype, iterator: *ffi.Value) void {
    // 3. Let innerResult be Completion(GetMethod(iterator, "return")).
    const caught = support.getCaught(at, iterator, "return") catch return;
    defer caught.release();
    // 4. If innerResult is a normal completion, then
    const method = switch (caught) {
        .normal => |m| m,
        .thrown => return,
    };
    //    a. Let return be innerResult.[[Value]].
    //    b. If return is undefined, return ? completion.
    if (ffi.v8_Value_IsUndefined(method) or ffi.v8_Value_IsNull(method)) return;
    //    c. Set innerResult to Completion(Call(return, iterator)).
    const inner = support.callCaught(at, method, iterator, &.{}) catch return;
    inner.release();
    // 5. If completion is a throw completion, return ? completion.
}

/// unwrap (AsyncFromSyncIteratorContinuation step 9): (v) =>
/// CreateIteratorResultObject(v, done), `done` its [[data]].
fn unwrapSteps(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const here = support.Here.ofCall(info) orelse return;
    defer here.deinit();
    const done_data = support.closureData(info);
    defer ffi.v8_Global_Dispose(done_data);
    const v = support.closureArgument(info, 0);
    defer ffi.v8_Global_Dispose(v);
    // 1. Return CreateIteratorResultObject(v, done).
    const result = support.iteratorResultObject(here, v, support.toBoolean(here, done_data)) catch return;
    support.closureReturn(info, result);
}

/// closeIterator (AsyncFromSyncIteratorContinuation step 13): (error) =>
/// IteratorClose(syncIteratorRecord, ThrowCompletion(error)), the sync
/// iterator its [[data]].
fn closeIteratorSteps(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const here = support.Here.ofCall(info) orelse return;
    defer here.deinit();
    const iterator = support.closureData(info);
    defer ffi.v8_Global_Dispose(iterator);
    // 1. Return ? IteratorClose(syncIteratorRecord, ThrowCompletion(error)):
    //    close, then throw error.
    closeQuietly(here, iterator);
    support.closureThrow(here.isolate, support.closureArgument(info, 0));
}

pub fn releaseIteratorRecord(record: *engine.IteratorRecord) void {
    Record.of(record).release();
}

// ============================================================================
// WebIDL: ECMAScript to IDL
// ============================================================================

/// WebIDL 3.2.21 steps 1-3 for `value`: the @@iterator method (OWNED), or
/// null when it is undefined. Not an Object is a TypeError (step 1).
fn sequenceMethod(entered: Entered, object: *ffi.Value) Error!?*ffi.Value {
    // 1. If V is not an Object, throw a TypeError.
    if (!ffi.v8_Value_IsObject(object)) return error.TypeError;
    // 2. Let method be ? GetMethod(V, %Symbol.iterator%).
    // 3. If method is undefined - throw a TypeError, or, for a union with a
    //    sequence member, that member does not apply: the caller's choice.
    return support.getSymbolMethod(entered, object, .iterator);
}

/// WebIDL "create a sequence from an iterable" (3.2.21.1), item by item:
/// `each` is given every item. Stops at the first error, without closing
/// the iterator, as the spec's conversion does.
fn createSequence(entered: Entered, object: *ffi.Value, method: *ffi.Value, allocator: Allocator, context: anytype, comptime each: fn (@TypeOf(context), *ffi.Value) Error!void) Error!void {
    // 1. Let iteratorRecord be ? GetIteratorFromMethod(iterable, method).
    const record = try getIteratorFromMethod(entered, object, method, .sync, allocator);
    defer record.release();
    // 2. Initialize i to be 0.
    // 3. Repeat
    while (true) {
        // 1. Let next be ? IteratorStepValue(iteratorRecord).
        // 2. If next is done, then return the sequence.
        const next = (try stepValue(entered, record)) orelse return;
        // 3. Initialize S_i to the result of converting next to an IDL value
        //    of type T (`each` takes `next`).
        // 4. Set i to i + 1.
        try each(context, next);
    }
}

/// WebIDL: every item of an iterable, `each` given it BORROWED; false when
/// `value` has no @@iterator.
pub fn iterate(realm: Context, value: JSValue, each: engine.IterateSteps, data: ?*anyopaque) Error!bool {
    const entered = try support.enter(realm);
    defer entered.leave();
    const object = try support.ownGlobal(entered, value);
    defer ffi.v8_Global_Dispose(object);
    const method = (try sequenceMethod(entered, object)) orelse return false;
    defer ffi.v8_Global_Dispose(method);

    const Each = struct {
        steps: engine.IterateSteps,
        data: ?*anyopaque,
        fn item(self: @This(), next: *ffi.Value) Error!void {
            defer ffi.v8_Global_Dispose(next);
            try self.steps(self.data, support.borrowed(next));
        }
    };
    try createSequence(entered, object, method, realm.allocator, Each{ .steps = each, .data = data }, Each.item);
    return true;
}

/// WebIDL sequence<any> (3.2.21): each item as it is. OWNED slice of OWNED
/// values.
pub fn convertToSequence(realm: Context, value: JSValue, allocator: Allocator) Error![]Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    const object = try support.ownGlobal(entered, value);
    defer ffi.v8_Global_Dispose(object);
    // 3. If method is undefined, throw a TypeError.
    const method = (try sequenceMethod(entered, object)) orelse return error.TypeError;
    defer ffi.v8_Global_Dispose(method);

    var items: std.ArrayListUnmanaged(Owned) = .empty;
    errdefer {
        for (items.items) |item| item.release();
        items.deinit(allocator);
    }
    const Collect = struct {
        items: *std.ArrayListUnmanaged(Owned),
        allocator: Allocator,
        fn item(self: @This(), next: *ffi.Value) Error!void {
            // 3. S_i is next converted to `any`: next itself.
            self.items.append(self.allocator, support.owned(next)) catch {
                ffi.v8_Global_Dispose(next);
                return error.OutOfMemory;
            };
        }
    };
    // 4. Return the result of creating a sequence from V and method.
    try createSequence(entered, object, method, allocator, Collect{ .items = &items, .allocator = allocator }, Collect.item);
    return items.toOwnedSlice(allocator) catch error.OutOfMemory;
}

/// The sequence member of a (sequence<sequence<S>> or record<S, S>) union -
/// URLSearchParams' and Headers' init - converted, then checked pair by
/// pair: null when `value` is not an Object with an @@iterator (the member
/// does not apply). OWNED.
pub fn convertToSequenceOfStringPairs(realm: Context, value: JSValue, conversion: engine.StringConversion, allocator: Allocator) Error!?[]engine.StringRecordEntry {
    const entered = try support.enter(realm);
    defer entered.leave();
    const object = try support.ownGlobal(entered, value);
    defer ffi.v8_Global_Dispose(object);
    // The union's sequence member applies to an Object with an @@iterator.
    if (!ffi.v8_Value_IsObject(object)) return null;
    const method = (try support.getSymbolMethod(entered, object, .iterator)) orelse return null;
    defer ffi.v8_Global_Dispose(method);

    // Converting to sequence<sequence<S>>: every inner sequence, every
    // string, before any pair is looked at - an exception converting a
    // later item wins over a wrong-sized earlier pair.
    var pairs: std.ArrayListUnmanaged([][]u8) = .empty;
    defer {
        for (pairs.items) |pair| freeStrings(pair, allocator);
        pairs.deinit(allocator);
    }
    const Outer = struct {
        const Self = @This();
        realm: Context,
        entered: Entered,
        pairs: *std.ArrayListUnmanaged([][]u8),
        conversion: engine.StringConversion,
        allocator: Allocator,
        fn item(self: @This(), next: *ffi.Value) Error!void {
            defer ffi.v8_Global_Dispose(next);
            // The item converted to sequence<S>: 3.2.21 again.
            const inner_method = (try sequenceMethod(self.entered, next)) orelse return error.TypeError;
            defer ffi.v8_Global_Dispose(inner_method);
            var strings: std.ArrayListUnmanaged([]u8) = .empty;
            errdefer {
                for (strings.items) |s| self.allocator.free(s);
                strings.deinit(self.allocator);
            }
            const Inner = struct {
                outer: Self,
                strings: *std.ArrayListUnmanaged([]u8),
                fn item(inner: @This(), element: *ffi.Value) Error!void {
                    defer ffi.v8_Global_Dispose(element);
                    const text = try convertString(inner.outer.realm, support.borrowed(element), inner.outer.conversion, inner.outer.allocator);
                    inner.strings.append(inner.outer.allocator, text) catch {
                        inner.outer.allocator.free(text);
                        return error.OutOfMemory;
                    };
                }
            };
            try createSequence(self.entered, next, inner_method, self.allocator, Inner{ .outer = self, .strings = &strings }, Inner.item);
            const pair = strings.toOwnedSlice(self.allocator) catch return error.OutOfMemory;
            self.pairs.append(self.allocator, pair) catch {
                freeStrings(pair, self.allocator);
                return error.OutOfMemory;
            };
        }
    };
    try createSequence(entered, object, method, allocator, Outer{ .realm = realm, .entered = entered, .pairs = &pairs, .conversion = conversion, .allocator = allocator }, Outer.item);

    // URLSearchParams' initialize step 1.1 and Headers' fill step 1.1: "If
    // pair's size is not 2, then throw a TypeError."
    for (pairs.items) |pair| if (pair.len != 2) return error.TypeError;
    const entries = allocator.alloc(engine.StringRecordEntry, pairs.items.len) catch return error.OutOfMemory;
    for (pairs.items, entries) |*pair, *entry| {
        // The entry takes the two strings; the pair's own slice goes.
        entry.* = .{ .key = pair.*[0], .value = pair.*[1] };
        allocator.free(pair.*);
        pair.* = pair.*[0..0];
    }
    return entries;
}

fn convertString(realm: Context, value: JSValue, conversion: engine.StringConversion, allocator: Allocator) Error![]u8 {
    const converted = switch (conversion) {
        .dom_string => webidl_conversions.convertToDOMString(realm, value, allocator),
        .usv_string => webidl_conversions.convertToUSVString(realm, value, allocator),
    };
    return converted catch |err| support.protocolError(err);
}

fn freeStrings(strings: [][]u8, allocator: Allocator) void {
    for (strings) |s| allocator.free(s);
    allocator.free(strings);
}

// ============================================================================
// WebIDL: IDL to ECMAScript
// ============================================================================

/// WebIDL "create a frozen array" (3.2.27) from `values`. OWNED.
pub fn createFrozenArray(realm: Context, values: []const JSValue) Error!Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    // 1. Let array be the result of converting the sequence of values of
    //    type T to a JavaScript value - a platform object to its wrapper in
    //    its relevant realm.
    const relevant = try support.RelevantList.of(entered.isolate, values);
    defer relevant.release();
    const array = webidl_conversions.createSequenceOfValues(realm, relevant.values) catch |err| return support.protocolError(err);
    const handle = support.handleOf(array) orelse return error.OperationFailed;
    errdefer ffi.v8_Global_Dispose(handle);
    // 2. Perform ! SetIntegrityLevel(array, "frozen").
    if (!ffi.v8_Object_Freeze(@ptrCast(handle), entered.context())) return error.OperationFailed;
    // 3. Return array.
    return support.owned(handle);
}
