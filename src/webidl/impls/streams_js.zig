//! JavaScript interop for the Streams implementation.
//!
//! The Streams algorithms are written in terms of four JavaScript notions -
//! values, promises you can settle, reactions to a promise, and invoking an
//! author callback - and each needs one exact behaviour that the older
//! streams code approximated (errors became TypeError strings, `start()` ran
//! with `this` undefined, a Local slot pointer was handed to APIs expecting a
//! Global). This file is that behaviour, once.
//!
//! ## One handle kind
//!
//! Every `Value` here is a V8 `Global<Value>*`. Never a Local slot pointer
//! from `v8_Global_Get` - passing one where a Global is expected reads the
//! object's map word as a handle location. A comment on each function says who
//! owns what it returns; "owned" means the caller disposes it exactly once.
//!
//! ## Lifetime of the objects the reactions point at
//!
//! Reaction data points at Zig instances (a controller, a stream). Those stay
//! valid because the wrapper cache holds every streams-graph wrapper strongly
//! until the realm is torn down (`wrapper_cache.isStreamsGraphObject`) - see
//! the reasoning there. Blink traces the same edges; this engine cannot.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

pub const Value = *ffi.Value;

pub const Error = error{
    /// A JavaScript exception is pending on the isolate; the binding lets it
    /// propagate instead of throwing a second one.
    ExceptionPending,
    NoIsolate,
    NoContext,
    OutOfMemory,
    /// V8 refused to create a value or run a call (termination, OOM).
    V8Failure,
};

/// The isolate and context a streams object runs in.
pub const Realm = struct {
    isolate: *ffi.Isolate,
    /// Borrowed: the runtime context's own Global<Context>*.
    context: *ffi.Context,

    pub fn of(instance: *const runtime.Instance) Error!Realm {
        return ofContext(instance.ctx);
    }

    pub fn ofContext(ctx: runtime.Context) Error!Realm {
        const isolate = ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const engine_ctx = ctx.engine_ctx orelse return error.NoContext;
        return .{ .isolate = isolate, .context = @ptrCast(@alignCast(engine_ctx)) };
    }

    // ------------------------------------------------------------------
    // Values
    // ------------------------------------------------------------------

    /// Owned.
    pub fn undefinedValue(self: Realm) Error!Value {
        return ffi.v8_Undefined(self.isolate) orelse error.V8Failure;
    }

    /// Owned.
    pub fn number(self: Realm, n: f64) Value {
        return @ptrCast(ffi.v8_Number_New(self.isolate, n));
    }

    /// Owned.
    pub fn string(self: Realm, s: []const u8) Error!Value {
        const str = if (s.len == 0)
            ffi.v8_String_Empty(self.isolate)
        else
            ffi.v8_String_NewFromUtf8(self.isolate, s.ptr, @intCast(s.len));
        return @ptrCast(str orelse return error.V8Failure);
    }

    /// Owned copy of a value the binding handed in. The binding never
    /// disposes a `runtime.JSValue` argument's handle (see
    /// `argHandleIsCopied`), and impl-to-impl callers keep theirs, so the
    /// argument is treated as BORROWED and cloned.
    pub fn fromRuntime(self: Realm, value: runtime.JSValue) Error!Value {
        return switch (value) {
            .undefined => self.undefinedValue(),
            .null => ffi.v8_Null(self.isolate) orelse error.V8Failure,
            .boolean => |b| ffi.v8_Boolean_New(self.isolate, b) orelse error.V8Failure,
            .number => |n| self.number(n),
            .string => |s| self.string(s.data),
            .handle => |h| clone(@ptrCast(@alignCast(h.ptr))),
            .instance => |i| clone(try self.wrap(i)),
        };
    }

    /// Owned; `.undefined` when the optional argument was not passed.
    pub fn fromOptional(self: Realm, value: anytype) Error!Value {
        return if (value.was_passed) self.fromRuntime(value.value) else self.undefinedValue();
    }

    /// Borrowed: the wrapper cache's own handle for `instance`, created on
    /// first use. Never dispose it.
    pub fn wrap(self: Realm, instance: *runtime.Instance) Error!Value {
        const wrapper = v8.conversions.instanceToV8(self.isolate, instance);
        if (ffi.v8_Value_IsUndefined(wrapper)) return error.V8Failure;
        return wrapper;
    }

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------

    /// Owned: a new TypeError of this realm.
    pub fn typeError(self: Realm, message: []const u8) Error!Value {
        const msg = ffi.v8_String_NewFromUtf8(self.isolate, message.ptr, @intCast(message.len)) orelse return error.V8Failure;
        defer ffi.v8_String_Dispose(msg);
        return ffi.v8_Exception_TypeErrorInContext(self.context, msg) orelse error.V8Failure;
    }

    /// Owned: a new RangeError of this realm.
    pub fn rangeError(self: Realm, message: []const u8) Error!Value {
        const msg = ffi.v8_String_NewFromUtf8(self.isolate, message.ptr, @intCast(message.len)) orelse return error.V8Failure;
        defer ffi.v8_String_Dispose(msg);
        return ffi.v8_Exception_RangeErrorInContext(self.context, msg) orelse error.V8Failure;
    }

    /// Throw `value` into the calling script. Returns the error an impl
    /// returns so the binding leaves the exception in flight.
    pub fn throwValue(self: Realm, value: Value) error{ExceptionPending} {
        ffi.v8_Isolate_ThrowException(self.isolate, value);
        return error.ExceptionPending;
    }

    // ------------------------------------------------------------------
    // Calls
    // ------------------------------------------------------------------

    /// Call `function` and return its completion. Both arms are owned.
    pub fn call(self: Realm, function: Value, this: ?Value, args: []const Value) Error!Completion {
        var threw: bool = true;
        const result = ffi.v8_Function_CallCatching(
            self.context,
            function,
            this,
            @intCast(args.len),
            if (args.len == 0) null else args.ptr,
            &threw,
        ) orelse return error.V8Failure;
        return if (threw) .{ .thrown = result } else .{ .normal = result };
    }

    /// WebIDL "invoke a callback function" whose return type is a promise:
    /// a throw becomes a rejected promise, a return value becomes "a promise
    /// resolved with" it. Owned.
    pub fn promiseCall(self: Realm, function: Value, this: ?Value, args: []const Value) Error!Value {
        const completion = try self.call(function, this, args);
        switch (completion) {
            .normal => |v| {
                defer dispose(v);
                return self.promiseResolvedWith(v);
            },
            .thrown => |e| {
                defer dispose(e);
                return self.promiseRejectedWith(e);
            },
        }
    }

    // ------------------------------------------------------------------
    // Promises
    // ------------------------------------------------------------------

    /// WebIDL "a promise resolved with": always a new promise, resolved with
    /// `value` - so a thenable is adopted, not returned. Owned.
    pub fn promiseResolvedWith(self: Realm, value: Value) Error!Value {
        var deferred = try Deferred.init(self);
        defer deferred.deinitResolverOnly();
        deferred.resolve(self, value);
        return deferred.promise;
    }

    /// Owned.
    pub fn promiseResolvedWithUndefined(self: Realm) Error!Value {
        const undef = try self.undefinedValue();
        defer dispose(undef);
        return self.promiseResolvedWith(undef);
    }

    /// WebIDL "a promise rejected with". Owned.
    pub fn promiseRejectedWith(self: Realm, reason: Value) Error!Value {
        var deferred = try Deferred.init(self);
        defer deferred.deinitResolverOnly();
        deferred.reject(self, reason);
        return deferred.promise;
    }

    /// Owned: a promise rejected with a new TypeError.
    pub fn promiseRejectedWithTypeError(self: Realm, message: []const u8) Error!Value {
        const err = try self.typeError(message);
        defer dispose(err);
        return self.promiseRejectedWith(err);
    }

    /// WebIDL "react to" `promise`. `ctx` must stay valid until one of the
    /// handlers runs. The settled value is borrowed by the handler.
    pub fn react(
        self: Realm,
        promise: Value,
        comptime Ctx: type,
        ctx: *Ctx,
        comptime on_fulfilled: fn (*Ctx, Value) void,
        comptime on_rejected: fn (*Ctx, Value) void,
    ) Error!void {
        const Trampoline = struct {
            fn run(data: ?*anyopaque, value: ?*ffi.Value, rejected: bool) callconv(.c) void {
                const c: *Ctx = @ptrCast(@alignCast(data.?));
                const v = value.?;
                defer dispose(v);
                if (rejected) on_rejected(c, v) else on_fulfilled(c, v);
            }
        };
        if (!ffi.v8_Promise_React(self.context, promise, Trampoline.run, ctx)) return error.V8Failure;
    }
};

/// The completion of a call: a normal return value or a thrown value.
pub const Completion = union(enum) {
    normal: Value,
    thrown: Value,

    pub fn deinit(self: Completion) void {
        switch (self) {
            .normal, .thrown => |v| dispose(v),
        }
    }
};

/// A promise together with the capability to settle it - the spec's
/// "a new promise", later "resolve"d or "reject"ed.
pub const Deferred = struct {
    resolver: *ffi.PromiseResolver,
    /// Owned Global of the promise itself.
    promise: Value,

    pub fn init(realm: Realm) Error!Deferred {
        const resolver = ffi.v8_PromiseResolver_New(realm.context) orelse return error.V8Failure;
        errdefer ffi.v8_PromiseResolver_Dispose(resolver);
        const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse return error.V8Failure;
        return .{ .resolver = resolver, .promise = @ptrCast(promise) };
    }

    /// A new promise already resolved with undefined.
    pub fn initResolved(realm: Realm) Error!Deferred {
        var d = try init(realm);
        const undef = try realm.undefinedValue();
        defer dispose(undef);
        d.resolve(realm, undef);
        return d;
    }

    /// A new promise already rejected with `reason`.
    pub fn initRejected(realm: Realm, reason: Value) Error!Deferred {
        var d = try init(realm);
        d.reject(realm, reason);
        return d;
    }

    /// Settling an already-settled promise is a no-op, as in the spec.
    pub fn resolve(self: Deferred, realm: Realm, value: Value) void {
        _ = ffi.v8_PromiseResolver_Resolve(self.resolver, realm.context, value);
    }

    pub fn resolveUndefined(self: Deferred, realm: Realm) void {
        const undef = realm.undefinedValue() catch return;
        defer dispose(undef);
        self.resolve(realm, undef);
    }

    pub fn reject(self: Deferred, realm: Realm, reason: Value) void {
        _ = ffi.v8_PromiseResolver_Reject(self.resolver, realm.context, reason);
    }

    /// [[PromiseState]] is "pending".
    pub fn isPending(self: Deferred) bool {
        return ffi.v8_Promise_State(@ptrCast(self.promise)) == 0;
    }

    /// Set [[PromiseIsHandled]] to true.
    pub fn markHandled(self: Deferred) void {
        ffi.v8_Promise_MarkAsHandled(self.promise);
    }

    /// The promise as a return value. Borrowed from this Deferred: the binding
    /// reads it synchronously, so it must outlive only the current call.
    pub fn returnValue(self: Deferred) runtime.JSValue {
        return toReturn(self.promise);
    }

    pub fn deinit(self: Deferred) void {
        ffi.v8_PromiseResolver_Dispose(self.resolver);
        dispose(self.promise);
    }

    /// Release the resolver, keeping `promise` for the caller.
    fn deinitResolverOnly(self: Deferred) void {
        ffi.v8_PromiseResolver_Dispose(self.resolver);
    }
};

/// Owned: a second Global for `value`.
pub fn clone(value: Value) Error!Value {
    return ffi.v8_Global_Clone(value) orelse error.V8Failure;
}

pub fn dispose(value: Value) void {
    ffi.v8_Global_Dispose(value);
}

pub fn disposeOptional(value: *?Value) void {
    if (value.*) |v| dispose(v);
    value.* = null;
}

/// A value as an impl return. The binding reads the handle synchronously and
/// never disposes it, so a handle the impl keeps (a stored promise) costs
/// nothing, and one made only to be returned is leaked by the binding - the
/// same contract as every `JSValue.fromPromise` return in the tree.
pub fn toReturn(value: Value) runtime.JSValue {
    return .{ .handle = .{ .ptr = @ptrCast(value), .needs_disposal = false, .handle_scope = .global } };
}

pub fn isUndefined(value: Value) bool {
    return ffi.v8_Value_IsUndefined(value);
}

pub fn isFunction(value: Value) bool {
    return ffi.v8_Value_IsFunction(value);
}

pub fn isObject(value: Value) bool {
    return ffi.v8_Value_IsObject(value);
}

/// Read one member of a dictionary being converted from `object` (WebIDL
/// §3.2.18 step "Let jsMemberValue be ? Get(jsDict, key)"). Owned, and null
/// when the member is undefined - i.e. not present. A throwing getter leaves
/// its exception pending and returns error.ExceptionPending.
pub fn getMember(realm: Realm, object: Value, key: []const u8) Error!?Value {
    const key_str = ffi.v8_String_NewFromUtf8(realm.isolate, key.ptr, @intCast(key.len)) orelse return error.V8Failure;
    defer ffi.v8_String_Dispose(key_str);
    const value = ffi.v8_Object_Get(@ptrCast(object), realm.context, @ptrCast(key_str)) orelse
        return error.ExceptionPending;
    if (isUndefined(value)) {
        dispose(value);
        return null;
    }
    return value;
}

/// A dictionary member whose type is a callback function: undefined means
/// absent, anything not callable is a TypeError (WebIDL §3.2.20). Owned.
pub fn getCallbackMember(realm: Realm, object: Value, key: []const u8) Error!?Value {
    const value = (try getMember(realm, object, key)) orelse return null;
    if (!isFunction(value)) {
        dispose(value);
        const err = try realm.typeError("dictionary member is not a function");
        defer dispose(err);
        return realm.throwValue(err);
    }
    return value;
}
