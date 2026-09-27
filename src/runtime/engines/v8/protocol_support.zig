//! What the V8 side of the engine protocol's operations share: entering a
//! realm, the protocol's errors, catching what script throws and handing it
//! back, and the engine values the operations make and read.
//!
//! Every handle here follows the adapter's rule: each `v8_*` call returning a
//! pointer made a Global the caller owns (AGENTS.md, "The C++ seam").

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const realm_entry = @import("realm_entry.zig");
const value_operations = @import("value_operations.zig");
const context_manager = @import("context_manager.zig");

pub const Error = engine.Error;
pub const Entered = realm_entry.Entered;

/// The runtime table's errors as the protocol's: the table's own failure
/// codes (NoEngine, PromiseError, ...) are all the engine failing.
pub fn protocolError(err: runtime.EngineError) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.TypeError => error.TypeError,
        error.ExceptionPending => error.ExceptionPending,
        error.DataCloneError => error.DataCloneError,
        error.NotSupported => error.NotSupported,
        error.NoEngine,
        error.OperationFailed,
        error.PromiseError,
        error.AsyncIteratorError,
        error.RegistrationFailed,
        error.ObjectCreationFailed,
        => error.OperationFailed,
    };
}

/// Enter `realm`: its agent, and a scope in its context.
pub fn enter(realm: engine.Context) Error!Entered {
    return realm_entry.enter(realm) catch |err| protocolError(err);
}

/// The Global a `.handle` value holds, BORROWED (a `.handle` is a Global
/// whichever way it is tagged); null for any other kind.
pub fn handleOf(value: engine.JSValue) ?*ffi.Value {
    return switch (value) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        else => null,
    };
}

/// A Global of the caller's own for any value - a platform object as its
/// wrapper, a primitive made in the entered realm. OWNED.
pub fn ownGlobal(entered: Entered, value: engine.JSValue) Error!*ffi.Value {
    return value_operations.ownHandle(entered.isolate, entered.context(), value) catch |err| protocolError(err);
}

/// An OWNED protocol value over a Global the FFI made.
pub fn owned(global: *ffi.Value) engine.Owned {
    return .{ .value = realm_entry.owned(global) };
}

/// A JSValue BORROWING a Global for a call.
pub fn borrowed(global: *ffi.Value) engine.JSValue {
    return .{ .handle = .{ .ptr = global, .needs_disposal = false } };
}

/// A new V8 string of `text`. An empty slice may have no usable `.ptr`, so
/// the empty string is V8's own. OWNED.
pub fn newString(isolate: *ffi.Isolate, text: []const u8) Error!*ffi.String {
    if (text.len == 0) return ffi.v8_String_Empty(isolate) orelse error.OperationFailed;
    return ffi.v8_String_NewFromUtf8(isolate, text.ptr, @intCast(text.len)) orelse error.OperationFailed;
}

/// Make a value caught under a TryCatch pending again, so it propagates to
/// the script that called the operation. Takes the handle.
pub fn rethrow(isolate: *ffi.Isolate, thrown: ?*ffi.Value) Error {
    if (thrown) |value| {
        defer ffi.v8_Global_Dispose(value);
        ffi.v8_Isolate_ThrowException(isolate, value);
    }
    return error.ExceptionPending;
}

/// Run `body.run()` under a TryCatch. Whether it threw; what it threw (OWNED,
/// or null when there is nothing to hand back) in `thrown`. The exception is
/// cleared.
pub fn catching(isolate: *ffi.Isolate, body: anytype, thrown: *?*ffi.Value) bool {
    const Body = @TypeOf(body.*);
    const Trampoline = struct {
        fn call(data: ?*anyopaque) callconv(.c) void {
            const self: *Body = @ptrCast(@alignCast(data.?));
            self.run();
        }
    };
    thrown.* = null;
    return ffi.v8_RunCatching(isolate, Trampoline.call, body, thrown);
}

/// A new TypeError of `context`'s realm, with `message`. OWNED.
pub fn newTypeError(isolate: *ffi.Isolate, context: *ffi.Context, message: []const u8) Error!*ffi.Value {
    const text = try newString(isolate, message);
    defer ffi.v8_String_Dispose(text);
    return ffi.v8_Exception_TypeErrorInContext(context, text) orelse error.OperationFailed;
}

/// Throw a new TypeError of the entered realm: the spec's "throw a
/// TypeError" where the operation must throw it itself (a completion it
/// hands back, a rejection).
pub fn throwTypeError(entered: Entered, message: []const u8) Error {
    const exception = try newTypeError(entered.isolate, entered.context(), message);
    return rethrow(entered.isolate, exception);
}

/// The realm the context manager hosts for `object`'s creation context - the
/// object's associated realm - or null when it is not one the engine hosts.
pub fn associatedRealm(object: *ffi.Value) ?engine.Context {
    const context = ffi.v8_Object_GetCreationContext(@ptrCast(object)) orelse return null;
    defer ffi.v8_Context_Dispose(context);
    return context_manager.get(context);
}

/// ECMAScript GetMethod(V, P) for an object V and a well-known symbol:
/// undefined (null here) when the property is undefined or null, a TypeError
/// when it is not callable. OWNED.
pub fn getSymbolMethod(entered: Entered, object: *ffi.Value, which: enum { iterator, async_iterator }) Error!?*ffi.Value {
    const isolate = entered.isolate;
    const symbol = switch (which) {
        .iterator => ffi.v8_Symbol_GetIterator(isolate),
        .async_iterator => ffi.v8_Symbol_GetAsyncIterator(isolate),
    } orelse return error.OperationFailed;
    defer ffi.v8_Symbol_Dispose(symbol);
    // 1. Let func be ? GetV(V, P).
    const func = ffi.v8_Object_GetPropertyWithSymbol(entered.context(), @ptrCast(object), symbol) orelse
        return error.ExceptionPending;
    // 2. If func is either undefined or null, return undefined.
    if (ffi.v8_Value_IsUndefined(func) or ffi.v8_Value_IsNull(func)) {
        ffi.v8_Global_Dispose(func);
        return null;
    }
    // 3. If IsCallable(func) is false, throw a TypeError exception.
    if (!ffi.v8_Value_IsFunction(func)) {
        ffi.v8_Global_Dispose(func);
        return error.TypeError;
    }
    // 4. Return func.
    return func;
}

/// Get(O, P) for a string key, rethrowing what a getter throws. OWNED.
pub fn get(entered: Entered, object: *ffi.Value, key: []const u8) Error!*ffi.Value {
    var threw = false;
    const result = ffi.v8_Object_GetCatching(entered.context(), object, key.ptr, @intCast(key.len), &threw);
    if (threw) return rethrow(entered.isolate, result);
    return result orelse error.OperationFailed;
}

/// Call(F, V, args), rethrowing what it throws. OWNED.
pub fn call(entered: Entered, function: *ffi.Value, receiver: ?*ffi.Value, args: []const *ffi.Value) Error!*ffi.Value {
    var threw = false;
    const result = ffi.v8_Function_CallCatching(entered.context(), function, receiver, @intCast(args.len), if (args.len == 0) null else args.ptr, &threw);
    if (threw) return rethrow(entered.isolate, result);
    return result orelse error.OperationFailed;
}

/// ToBoolean(V).
pub fn toBoolean(entered: Entered, value: *ffi.Value) bool {
    return ffi.v8_Value_BooleanValue(value, entered.isolate);
}

/// ECMAScript Type(V) of an engine value.
pub fn typeOfValue(value: *ffi.Value) engine.ValueType {
    if (ffi.v8_Value_IsUndefined(value)) return .undefined;
    if (ffi.v8_Value_IsNull(value)) return .null;
    if (ffi.v8_Value_IsBoolean(value)) return .boolean;
    if (ffi.v8_Value_IsNumber(value)) return .number;
    if (ffi.v8_Value_IsString(value)) return .string;
    if (ffi.v8_Value_IsSymbol(value)) return .symbol;
    if (ffi.v8_Value_IsBigInt(value)) return .bigint;
    return .object;
}

/// CreateIteratorResultObject(value, done) in the entered realm: an ordinary
/// object with `value` and `done` data properties. OWNED.
pub fn iteratorResultObject(entered: Entered, value: *ffi.Value, done: bool) Error!*ffi.Value {
    const isolate = entered.isolate;
    const context = entered.context();
    // 1. Let obj be OrdinaryObjectCreate(%Object.prototype%).
    const object = ffi.v8_Object_NewInContext(context) orelse return error.OperationFailed;
    errdefer ffi.v8_Object_Dispose(object);
    // 2. Perform ! CreateDataPropertyOrThrow(obj, "value", value).
    const value_key = try newString(isolate, "value");
    defer ffi.v8_String_Dispose(value_key);
    if (!ffi.v8_Object_CreateDataProperty(object, context, value_key, value)) return error.OperationFailed;
    // 3. Perform ! CreateDataPropertyOrThrow(obj, "done", done).
    const done_key = try newString(isolate, "done");
    defer ffi.v8_String_Dispose(done_key);
    const done_value = ffi.v8_Boolean_New(isolate, done) orelse return error.OperationFailed;
    defer ffi.v8_Value_Dispose(done_value);
    if (!ffi.v8_Object_CreateDataProperty(object, context, done_key, done_value)) return error.OperationFailed;
    // 4. Return obj.
    return @ptrCast(object);
}
