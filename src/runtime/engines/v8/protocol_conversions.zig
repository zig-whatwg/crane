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
//! Deviations: GetIterator of a primitive (GetV's ToObject) is a TypeError -
//! V8's embedder API reads properties of objects only - and an async
//! iterator over a sync iterable (CreateAsyncFromSyncIterator) is not built:
//! its continuation needs a closure per step, which the FFI makes only per
//! context (see createAsyncIterator).

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
    // GetMethod's GetV: an object's property (the deviation above).
    if (!ffi.v8_Value_IsObject(object)) return error.TypeError;

    const method: ?*ffi.Value = switch (kind) {
        // 1. If kind is async, then
        .async => blk: {
            // a. Let method be ? GetMethod(obj, %Symbol.asyncIterator%).
            if (try support.getSymbolMethod(entered, object, .async_iterator)) |async_method| break :blk async_method;
            // b. If method is undefined, then
            //    i. Let syncMethod be ? GetMethod(obj, %Symbol.iterator%).
            //    ii. If syncMethod is undefined, throw a TypeError exception.
            const sync_method = (try support.getSymbolMethod(entered, object, .iterator)) orelse return error.TypeError;
            ffi.v8_Global_Dispose(sync_method);
            //    iii. Let syncIteratorRecord be ? GetIteratorFromMethod(obj,
            //         syncMethod).
            //    iv. Return CreateAsyncFromSyncIterator(syncIteratorRecord).
            // TODO(protocol): implement - design 4.6 (CreateAsyncFromSyncIterator: a closure per continuation step, which the FFI makes only per context)
            return error.NotSupported;
        },
        // 2. Otherwise, let method be ? GetMethod(obj, %Symbol.iterator%).
        .sync => try support.getSymbolMethod(entered, object, .iterator),
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
    return support.owned(try iteratorNextValue(entered, Record.of(record)));
}

/// The iterator's `return` called with `value` - IteratorClose's and
/// AsyncIteratorClose's call, and Streams' cancel steps for an iterable:
/// its result (OWNED), or null when the iterator has no `return`.
pub fn iteratorReturn(realm: Context, record: *engine.IteratorRecord, value: JSValue) Error!?Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    const self = Record.of(record);
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
    // 1. Let array be the result of converting the sequence of values of
    //    type T to a JavaScript value.
    const array = webidl_conversions.createSequenceOfValues(realm, values) catch |err| return support.protocolError(err);
    const handle = support.handleOf(array) orelse return error.OperationFailed;
    errdefer ffi.v8_Global_Dispose(handle);
    // 2. Perform ! SetIntegrityLevel(array, "frozen").
    const entered = try support.enter(realm);
    defer entered.leave();
    if (!ffi.v8_Object_Freeze(@ptrCast(handle), entered.context())) return error.OperationFailed;
    // 3. Return array.
    return support.owned(handle);
}
