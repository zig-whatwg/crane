//! WebIDL conversions (WebIDL § 3.2) of arguments an impl takes unconverted,
//! as V8 implements them for the Engine table - the shared set every lane's
//! impls lean on (AGENTS.md, "The engine boundary"):
//!
//! - convertToSequenceOfPlatformObjects, convertToSequenceOfObjects and
//!   convertToSequenceOfDOMStrings: "convert an ECMAScript value to
//!   sequence<T>" (3.2.21), through the value's iterator;
//! - convertToDOMString and convertToUSVString (3.2.10, 3.2.12);
//! - convertToRecordOfStrings: "convert to record<K, V>" (3.2.23) for string
//!   K and V;
//! - convertToPlatformObject (an interface type, 3.2.15, without the brand
//!   check);
//! - getCopyOfBufferSourceBytes ("get a copy of the bytes held by the buffer
//!   source", 3.2.26) and createSequenceOfValues (a sequence back to an
//!   Array).
//!
//! Every function enters the realm it is given, so a caller needs no scope.
//! What script throws while converting is left pending (ExceptionPending), so
//! the binding lets it propagate.

const std = @import("std");
const runtime = @import("runtime");
const EngineError = runtime.EngineError;

const ffi = @import("ffi.zig");
const engine = @import("engine.zig");
const conversions = @import("conversions.zig");
const value_operations = @import("value_operations.zig");

const ownHandle = value_operations.ownHandle;

/// Rethrow a value a Catching call caught, so it propagates to the script
/// that called the operation. Takes the handle.
fn rethrow(isolate: *ffi.Isolate, thrown: ?*ffi.Value) EngineError {
    if (thrown) |value| {
        defer ffi.v8_Global_Dispose(value);
        ffi.v8_Isolate_ThrowException(isolate, value);
    }
    return EngineError.ExceptionPending;
}

/// Get(`object`, `key`), rethrowing what a getter throws. OWNED result.
fn getOrRethrow(isolate: *ffi.Isolate, context: *ffi.Context, object: *ffi.Value, key: []const u8) EngineError!*ffi.Value {
    var threw = false;
    const result = ffi.v8_Object_GetCatching(context, object, key.ptr, @intCast(key.len), &threw);
    if (threw) return rethrow(isolate, result);
    return result orelse EngineError.OperationFailed;
}

/// Call(`function`, `receiver`), rethrowing what it throws. OWNED result.
fn callOrRethrow(isolate: *ffi.Isolate, context: *ffi.Context, function: *ffi.Value, receiver: *ffi.Value) EngineError!*ffi.Value {
    var threw = false;
    const result = ffi.v8_Function_CallCatching(context, function, receiver, 0, null, &threw);
    if (threw) return rethrow(isolate, result);
    return result orelse EngineError.OperationFailed;
}

/// WebIDL 3.2.21 steps 1-3 and "create a sequence from an iterable" for
/// `value`: the items, each an OWNED Global the caller disposes, in order -
/// or null when `value` is an object whose @@iterator is undefined.
/// Conversion of each item to T is the caller's.
fn iterateIfIterable(
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    value: runtime.JSValue,
    allocator: std.mem.Allocator,
) EngineError!?[]*ffi.Value {
    // Step 1: If V is not an Object, throw a TypeError.
    const handle = switch (value) {
        .handle => |h| h,
        else => return EngineError.TypeError,
    };
    // Our own Global for V, whichever kind of handle it arrived as.
    const object = try ownHandle(isolate, context, .{ .handle = handle });
    defer ffi.v8_Global_Dispose(object);
    if (!ffi.v8_Value_IsObject(object)) return EngineError.TypeError;

    // Step 2: Let method be ? GetMethod(V, %Symbol.iterator%).
    const symbol = ffi.v8_Symbol_GetIterator(isolate) orelse return EngineError.OperationFailed;
    defer ffi.v8_Symbol_Dispose(symbol);
    const method = ffi.v8_Object_GetPropertyWithSymbol(context, @ptrCast(object), symbol) orelse
        return EngineError.ExceptionPending;
    defer ffi.v8_Global_Dispose(method);
    // Step 3: If method is undefined, throw a TypeError - or, for a union
    // with a sequence member, that member does not apply: null. (GetMethod
    // throws a TypeError for anything else that is not callable.)
    if (ffi.v8_Value_IsUndefined(method) or ffi.v8_Value_IsNull(method)) return null;
    if (!ffi.v8_Value_IsFunction(method)) return EngineError.TypeError;

    // Step 4: "create a sequence from an iterable":
    // 1. Let iteratorRecord be ? GetIteratorFromMethod(iterable, method).
    const iterator = try callOrRethrow(isolate, context, method, object);
    defer ffi.v8_Global_Dispose(iterator);
    if (!ffi.v8_Value_IsObject(iterator)) return EngineError.TypeError;
    const next = try getOrRethrow(isolate, context, iterator, "next");
    defer ffi.v8_Global_Dispose(next);
    // Calling a `next` that is not callable is a TypeError.
    if (!ffi.v8_Value_IsFunction(next)) return EngineError.TypeError;

    // 2. Initialize i to be 0.
    var items: std.ArrayListUnmanaged(*ffi.Value) = .empty;
    errdefer {
        for (items.items) |item| ffi.v8_Global_Dispose(item);
        items.deinit(allocator);
    }
    // 3. Repeat:
    while (true) {
        // 1. Let next be ? IteratorStepValue(iteratorRecord).
        const result = try callOrRethrow(isolate, context, next, iterator);
        defer ffi.v8_Global_Dispose(result);
        if (!ffi.v8_Value_IsObject(result)) return EngineError.TypeError;
        const done = try getOrRethrow(isolate, context, result, "done");
        const finished = ffi.v8_Value_BooleanValue(done, isolate);
        ffi.v8_Global_Dispose(done);
        // 2. If next is DONE, then return an IDL sequence value of length i.
        if (finished) break;
        const item = try getOrRethrow(isolate, context, result, "value");
        items.append(allocator, item) catch {
            ffi.v8_Global_Dispose(item);
            return EngineError.OutOfMemory;
        };
        // 3-4. Converting the item is the caller's; i + 1.
    }
    return items.toOwnedSlice(allocator) catch EngineError.OutOfMemory;
}

/// `iterateIfIterable`, where no @@iterator is the spec's TypeError.
fn iterate(
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    value: runtime.JSValue,
    allocator: std.mem.Allocator,
) EngineError![]*ffi.Value {
    return (try iterateIfIterable(isolate, context, value, allocator)) orelse EngineError.TypeError;
}

fn disposeAll(items: []*ffi.Value, allocator: std.mem.Allocator) void {
    for (items) |item| ffi.v8_Global_Dispose(item);
    allocator.free(items);
}

/// Engine table `convertToSequenceOfPlatformObjects`: WebIDL 3.2.21 "convert
/// an ECMAScript value to sequence<T>" for an interface type T. OWNED slice.
pub fn convertToSequenceOfPlatformObjects(
    realm: runtime.Context,
    value: runtime.JSValue,
    allocator: std.mem.Allocator,
) EngineError![]*runtime.Instance {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const isolate = entered.isolate;
    const context = entered.scope.context;

    const items = try iterate(isolate, context, value, allocator);
    defer disposeAll(items, allocator);
    const instances = allocator.alloc(*runtime.Instance, items.len) catch return EngineError.OutOfMemory;
    errdefer allocator.free(instances);
    for (items, 0..) |item, i| {
        // Step 3.3 of "create a sequence": the item converted to T - an
        // interface type: it must implement an interface, or TypeError. The
        // binding's own unwrap rule.
        instances[i] = conversions.fromV8Value(*runtime.Instance, allocator, isolate, context, item) catch
            return EngineError.TypeError;
    }
    return instances;
}

/// Engine table `convertToSequenceOfObjects`: WebIDL 3.2.21 for
/// sequence<object>. OWNED slice of OWNED handles.
pub fn convertToSequenceOfObjects(
    realm: runtime.Context,
    value: runtime.JSValue,
    allocator: std.mem.Allocator,
) EngineError![]runtime.JSValue {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();

    const items = try iterate(entered.isolate, entered.scope.context, value, allocator);
    // An item that is not an object is a TypeError (the conversion to
    // `object`), and then every item is released.
    for (items) |item| {
        if (!ffi.v8_Value_IsObject(item)) {
            disposeAll(items, allocator);
            return EngineError.TypeError;
        }
    }
    defer allocator.free(items);
    const values = allocator.alloc(runtime.JSValue, items.len) catch {
        for (items) |item| ffi.v8_Global_Dispose(item);
        return EngineError.OutOfMemory;
    };
    for (items, 0..) |item, i| {
        values[i] = .{ .handle = .{ .ptr = @ptrCast(item), .needs_disposal = true, .handle_scope = .global } };
    }
    return values;
}

/// WebIDL "convert to sequence<DOMString>" (Engine table
/// `convertToSequenceOfDOMStrings`). OWNED strings and slice; null when
/// `value` has no @@iterator.
pub fn convertToSequenceOfDOMStrings(
    realm: runtime.Context,
    value: runtime.JSValue,
    allocator: std.mem.Allocator,
) EngineError!?[][]u8 {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const isolate = entered.isolate;
    const context = entered.scope.context;

    const items = (try iterateIfIterable(isolate, context, value, allocator)) orelse return null;
    defer disposeAll(items, allocator);
    const strings = allocator.alloc([]u8, items.len) catch return EngineError.OutOfMemory;
    var made: usize = 0;
    errdefer {
        for (strings[0..made]) |string| allocator.free(string);
        allocator.free(strings);
    }
    for (items) |item| {
        // Each item converted to DOMString.
        strings[made] = try toStringOf(isolate, context, item, allocator);
        made += 1;
    }
    return strings;
}

/// ToString(`value`) as UTF-8 (WTF-8 for a lone surrogate): OWNED. A Symbol
/// is a TypeError with nothing thrown; what a toString throws is left
/// pending.
fn toStringOf(isolate: *ffi.Isolate, context: *ffi.Context, value: *ffi.Value, allocator: std.mem.Allocator) EngineError![]u8 {
    if (ffi.v8_Value_IsSymbol(value)) return EngineError.TypeError;
    const result = ffi.v8_Value_ToString_Safe(value, context);
    defer ffi.v8_FreeToStringResult(result);
    if (result.exception) |exception| {
        ffi.v8_Isolate_ThrowException(isolate, exception);
        return EngineError.ExceptionPending;
    }
    const string = result.value orelse return EngineError.OperationFailed;
    const length = ffi.v8_String_Utf8Length(string);
    if (length <= 0) return allocator.alloc(u8, 0) catch EngineError.OutOfMemory;
    const buffer = allocator.alloc(u8, @intCast(length)) catch return EngineError.OutOfMemory;
    _ = ffi.v8_String_WriteUtf8(string, buffer.ptr, length);
    return buffer;
}

/// `value` as a DOMString, whatever kind of JSValue it arrived as. OWNED.
fn convertToString(realm: runtime.Context, value: runtime.JSValue, allocator: std.mem.Allocator) EngineError![]u8 {
    // A string the binding already has needs no engine.
    if (value == .string) return allocator.dupe(u8, value.string.data) catch EngineError.OutOfMemory;
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const handle = try ownHandle(entered.isolate, entered.scope.context, value);
    defer ffi.v8_Global_Dispose(handle);
    return toStringOf(entered.isolate, entered.scope.context, handle, allocator);
}

/// Engine table `convertToDOMString`: WebIDL 3.2.10. OWNED.
pub fn convertToDOMString(realm: runtime.Context, value: runtime.JSValue, allocator: std.mem.Allocator) EngineError![]u8 {
    return convertToString(realm, value, allocator);
}

/// Engine table `convertToUSVString`: WebIDL 3.2.12 - the DOMString, with
/// every lone surrogate replaced by U+FFFD. OWNED.
pub fn convertToUSVString(realm: runtime.Context, value: runtime.JSValue, allocator: std.mem.Allocator) EngineError![]u8 {
    const string = try convertToString(realm, value, allocator);
    conversions.replaceLoneSurrogates(string);
    return string;
}

/// `value` converted to the string type `to`: ToString (a Symbol is a
/// TypeError), and for a USVString its lone surrogates replaced. OWNED.
fn toStringType(isolate: *ffi.Isolate, context: *ffi.Context, value: *ffi.Value, to: runtime.StringConversion, allocator: std.mem.Allocator) EngineError![]u8 {
    const string = try toStringOf(isolate, context, value, allocator);
    if (to == .usv_string) conversions.replaceLoneSurrogates(string);
    return string;
}

/// Engine table `convertToRecordOfStrings`: WebIDL 3.2.23 "convert to
/// record<K, V>" for string K and V. OWNED (`StringRecordEntry.freeAll`).
pub fn convertToRecordOfStrings(
    realm: runtime.Context,
    value: runtime.JSValue,
    keys: runtime.StringConversion,
    values: runtime.StringConversion,
    allocator: std.mem.Allocator,
) EngineError![]runtime.StringRecordEntry {
    // 1. If O is not an Object, throw a TypeError.
    if (value != .handle) return EngineError.TypeError;
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const isolate = entered.isolate;
    const context = entered.scope.context;
    const object = try ownHandle(isolate, context, value);
    defer ffi.v8_Global_Dispose(object);
    if (!ffi.v8_Value_IsObject(object)) return EngineError.TypeError;

    // 2. Let result be a new empty instance of record<K, V> - an ordered map,
    // indexed by key for "set" (a USVString key can repeat an earlier one).
    var result: std.ArrayListUnmanaged(runtime.StringRecordEntry) = .empty;
    var index: std.StringHashMapUnmanaged(usize) = .empty;
    defer index.deinit(allocator);
    errdefer {
        for (result.items) |entry| {
            allocator.free(entry.key);
            allocator.free(entry.value);
        }
        result.deinit(allocator);
    }

    // 3. Let keys be ? O.[[OwnPropertyKeys]]().
    var threw = false;
    const own_keys = ffi.v8_Object_OwnPropertyKeysCatching(context, object, &threw);
    if (threw) return rethrow(isolate, own_keys);
    const key_array: *ffi.Array = @ptrCast(own_keys orelse return EngineError.OperationFailed);
    defer ffi.v8_Global_Dispose(@ptrCast(key_array));

    // 4. For each key of keys:
    const count = ffi.v8_Array_Length(key_array);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const key = ffi.v8_Array_Get(context, key_array, i) orelse return EngineError.OperationFailed;
        defer ffi.v8_Global_Dispose(key);
        // 1. Let desc be ? O.[[GetOwnProperty]](key).
        var enumerable = false;
        const thrown = ffi.v8_Object_IsOwnEnumerableCatching(context, object, key, &enumerable, &threw);
        if (threw) return rethrow(isolate, thrown);
        // 2. If desc is not undefined and desc.[[Enumerable]] is true:
        if (!enumerable) continue;
        // 1. Let typedKey be key converted to an IDL value of type K.
        const typed_key = try toStringType(isolate, context, key, keys, allocator);
        var key_owned = true;
        defer if (key_owned) allocator.free(typed_key);
        // 2. Let value be ? Get(O, key).
        const item = ffi.v8_Object_GetByKeyCatching(context, object, key, &threw);
        if (threw) return rethrow(isolate, item);
        const item_value = item orelse return EngineError.OperationFailed;
        defer ffi.v8_Global_Dispose(item_value);
        // 3. Let typedValue be value converted to an IDL value of type V.
        const typed_value = try toStringType(isolate, context, item_value, values, allocator);
        // 4. Set result[typedKey] to typedValue: in place when typedKey is
        // already there, else appended.
        if (index.get(typed_key)) |at| {
            allocator.free(result.items[at].value);
            result.items[at].value = typed_value;
            continue;
        }
        result.append(allocator, .{ .key = typed_key, .value = typed_value }) catch {
            allocator.free(typed_value);
            return EngineError.OutOfMemory;
        };
        key_owned = false;
        index.put(allocator, typed_key, result.items.len - 1) catch return EngineError.OutOfMemory;
    }
    // 5. Return result.
    return result.toOwnedSlice(allocator) catch EngineError.OutOfMemory;
}

/// Engine table `convertToPlatformObject`: the platform object `value` is,
/// or null.
pub fn convertToPlatformObject(realm: runtime.Context, value: runtime.JSValue) ?*runtime.Instance {
    switch (value) {
        .instance => |instance| return instance,
        .handle => {},
        else => return null,
    }
    const entered = engine.enterRealm(realm) catch return null;
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const handle = ownHandle(entered.isolate, entered.scope.context, value) catch return null;
    defer ffi.v8_Global_Dispose(handle);
    if (!ffi.v8_Value_IsObject(handle) or ffi.v8_Value_IsFunction(handle)) return null;
    // The binding's own unwrap rule for an interface-typed value.
    return conversions.fromV8Value(*runtime.Instance, std.heap.page_allocator, entered.isolate, entered.scope.context, handle) catch null;
}

/// Engine table `getCopyOfBufferSourceBytes`: WebIDL "get a copy of the
/// bytes held by the buffer source". OWNED; null when not a BufferSource.
pub fn getCopyOfBufferSourceBytes(realm: runtime.Context, value: runtime.JSValue, allocator: std.mem.Allocator) EngineError!?[]u8 {
    if (value != .handle) return null;
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const handle = try ownHandle(entered.isolate, entered.scope.context, value);
    defer ffi.v8_Global_Dispose(handle);

    if (ffi.v8_Value_IsArrayBuffer(handle)) {
        // 1-2. An ArrayBuffer: its bytes (none when detached).
        const buffer: *ffi.ArrayBuffer = @ptrCast(handle);
        const length = ffi.v8_ArrayBuffer_ByteLength(buffer);
        if (length == 0) return allocator.alloc(u8, 0) catch EngineError.OutOfMemory;
        const data = ffi.v8_ArrayBuffer_Data(buffer) orelse return allocator.alloc(u8, 0) catch EngineError.OutOfMemory;
        const bytes: [*]const u8 = @ptrCast(data);
        return allocator.dupe(u8, bytes[0..length]) catch EngineError.OutOfMemory;
    }
    if (ffi.v8_Value_IsArrayBufferView(handle)) {
        // A view: the bytes it describes of its buffer, not the whole buffer.
        var info: ffi.ViewInfo = undefined;
        if (!ffi.v8_ArrayBufferView_Describe(handle, &info)) return EngineError.TypeError;
        // BufferSource is not [AllowShared].
        if (info.buffer_shared) return EngineError.TypeError;
        if (info.byte_length == 0 or info.buffer_detached) return allocator.alloc(u8, 0) catch EngineError.OutOfMemory;
        const buffer = ffi.v8_ArrayBufferView_Buffer(handle) orelse return EngineError.OperationFailed;
        defer ffi.v8_Global_Dispose(buffer);
        const data = ffi.v8_ArrayBuffer_Data(@ptrCast(buffer)) orelse return allocator.alloc(u8, 0) catch EngineError.OutOfMemory;
        const bytes: [*]const u8 = @ptrCast(data);
        return allocator.dupe(u8, bytes[info.byte_offset..][0..info.byte_length]) catch EngineError.OutOfMemory;
    }
    return null;
}

/// Engine table `createSequenceOfValues`: an Array of `realm` holding
/// `values` (borrowed). OWNED.
pub fn createSequenceOfValues(realm: runtime.Context, values: []const runtime.JSValue) EngineError!runtime.JSValue {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const context = entered.scope.context;
    const array = ffi.v8_Array_NewInContext(context, @intCast(values.len)) orelse return EngineError.OperationFailed;
    errdefer ffi.v8_Array_Dispose(array);
    for (values, 0..) |value, i| {
        const item = try ownHandle(entered.isolate, context, value);
        defer ffi.v8_Global_Dispose(item);
        if (!ffi.v8_Array_Set(array, context, @intCast(i), item)) return EngineError.OperationFailed;
    }
    return .{ .handle = .{ .ptr = @ptrCast(array), .needs_disposal = true, .handle_scope = .global } };
}
