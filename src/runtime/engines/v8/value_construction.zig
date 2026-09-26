//! Values an impl makes for script, and microtasks it queues - the V8 side of
//! the runtime-impls lane's Engine operations (AGENTS.md, "The engine
//! boundary"): createResolvedPromise, createRejectedPromise,
//! createSimpleException, createDictionaryObject and queueMicrotask.
//!
//! Each takes the realm as a runtime.Context and hands back only what its
//! declaration in src/runtime/engine_interface.zig says: an OWNED persistent
//! handle (`.handle`, needs_disposal) the caller releases with releaseValue or
//! returns to the binding. Every V8 handle made along the way is released
//! here - "every `v8_*` return is owned" is this file's rule, not the
//! caller's.

const std = @import("std");
const runtime = @import("runtime");
const EngineError = runtime.EngineError;
const JSValue = runtime.JSValue;

const ffi = @import("ffi.zig");
const realm_entry = @import("realm_entry.zig");
const enter = realm_entry.enter;
const agentOf = realm_entry.agentOf;
const EngineValue = realm_entry.EngineValue;
const owned = realm_entry.owned;

/// A new V8 string of `text`. An empty Zig slice may have no usable `.ptr`,
/// so the empty string is V8's own.
fn newString(isolate: *ffi.Isolate, text: []const u8) EngineError!*ffi.String {
    if (text.len == 0) return ffi.v8_String_Empty(isolate) orelse EngineError.OperationFailed;
    return ffi.v8_String_NewFromUtf8(isolate, text.ptr, @intCast(text.len)) orelse EngineError.OperationFailed;
}

// ============================================================================
// Promises
// ============================================================================

/// A settled promise of `realm`: fulfilled with `value`, or rejected with it.
fn settledPromise(realm: runtime.Context, value: JSValue, fulfilled: bool) EngineError!JSValue {
    const entered = try enter(realm);
    defer entered.leave();
    const context = entered.context();

    const settle_with = try EngineValue.of(entered.isolate, context, value);
    defer settle_with.release();

    const resolver = ffi.v8_PromiseResolver_New(context) orelse return EngineError.PromiseError;
    // Nothing settles the promise again once this call returns.
    defer ffi.v8_PromiseResolver_Dispose(resolver);
    const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse return EngineError.PromiseError;
    errdefer ffi.v8_Promise_Dispose(promise);

    const settled = if (fulfilled)
        ffi.v8_PromiseResolver_Resolve(resolver, context, settle_with.ptr)
    else
        ffi.v8_PromiseResolver_Reject(resolver, context, settle_with.ptr);
    if (!settled) return EngineError.PromiseError;
    return owned(@ptrCast(promise));
}

pub fn createResolvedPromise(realm: runtime.Context, value: JSValue) EngineError!JSValue {
    return settledPromise(realm, value, true);
}

pub fn createRejectedPromise(realm: runtime.Context, reason: JSValue) EngineError!JSValue {
    return settledPromise(realm, reason, false);
}

// ============================================================================
// Exceptions
// ============================================================================

/// WebIDL "create a simple exception": Construct(%kind%, « message ») with the
/// realm's intrinsic. V8's embedder API (v8::Exception, created in the realm's
/// context) reaches the intrinsic for TypeError, RangeError and
/// ReferenceError; it has no EvalError or URIError, so those two are
/// NotSupported - Blink's V8ThrowException creates neither either.
pub fn createSimpleException(realm: runtime.Context, kind: runtime.SimpleExceptionKind, message: []const u8) EngineError!JSValue {
    const entered = try enter(realm);
    defer entered.leave();
    const context = entered.context();

    const text = try newString(entered.isolate, message);
    defer ffi.v8_String_Dispose(text);

    const exception = switch (kind) {
        .TypeError => ffi.v8_Exception_TypeErrorInContext(context, text),
        .RangeError => ffi.v8_Exception_RangeErrorInContext(context, text),
        .ReferenceError => ffi.v8_Exception_ReferenceErrorInContext(context, text),
        .EvalError, .URIError => return EngineError.NotSupported,
    } orelse return EngineError.OperationFailed;
    return owned(@ptrCast(exception));
}

// ============================================================================
// Dictionaries
// ============================================================================

/// WebIDL § 3.2.17, an IDL dictionary value to an ECMAScript Object:
/// OrdinaryObjectCreate(%Object.prototype%), then CreateDataPropertyOrThrow for
/// each present member in the order given.
pub fn createDictionaryObject(realm: runtime.Context, members: []const runtime.DictionaryMember) EngineError!JSValue {
    const entered = try enter(realm);
    defer entered.leave();
    const context = entered.context();

    // Step 1: O = OrdinaryObjectCreate(%Object.prototype%) of this realm.
    const object = ffi.v8_Object_NewInContext(context) orelse return EngineError.ObjectCreationFailed;
    errdefer ffi.v8_Object_Dispose(object);

    // Steps 2-3: each member, CreateDataPropertyOrThrow(O, key, value).
    for (members) |member| {
        const key = try newString(entered.isolate, member.name);
        defer ffi.v8_String_Dispose(key);
        const value = try EngineValue.of(entered.isolate, context, member.value);
        defer value.release();
        // "!": an ordinary extensible object with no such property accepts it.
        if (!ffi.v8_Object_CreateDataProperty(object, context, key, value.ptr)) return EngineError.OperationFailed;
    }

    // Step 4.
    return owned(@ptrCast(object));
}

// ============================================================================
// Microtasks
// ============================================================================

/// A queued microtask's steps and their data, until the microtask runs.
const QueuedMicrotask = struct {
    steps: runtime.RealmSteps,
    data: ?*anyopaque,
};

/// V8 runs a callback microtask as `void (*)(void*)`.
fn runQueuedMicrotask(raw: ?*anyopaque) callconv(.c) void {
    const queued: *QueuedMicrotask = @ptrCast(@alignCast(raw orelse return));
    const steps = queued.steps;
    const data = queued.data;
    std.heap.c_allocator.destroy(queued);
    steps(data);
}

/// HTML "queue a microtask" on `realm`'s agent. V8 drops a queued callback
/// microtask when its isolate is disposed, so a record still queued then is
/// never freed - the declaration says the steps may not run.
pub fn queueMicrotask(realm: runtime.Context, steps: runtime.RealmSteps, data: ?*anyopaque) EngineError!void {
    const isolate = agentOf(realm) orelse return EngineError.OperationFailed;
    const queued = std.heap.c_allocator.create(QueuedMicrotask) catch return EngineError.OutOfMemory;
    queued.* = .{ .steps = steps, .data = data };
    ffi.v8_Isolate_EnqueueMicrotask(isolate, @ptrCast(&runQueuedMicrotask), queued);
}
