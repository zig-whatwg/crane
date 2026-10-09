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
const conversions = @import("conversions.zig");

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
/// wrapper in its relevant realm (`relevantWrapper`), a primitive made in the
/// realm `at` is in. OWNED.
///
/// `at`, here and below: where the work happens - an Entered realm, or a
/// Here inside a native closure; anything with an `isolate` and a
/// `context()`.
pub fn ownGlobal(at: anytype, value: engine.JSValue) Error!*ffi.Value {
    return switch (value) {
        .instance => |instance| relevantWrapper(at.isolate, instance),
        else => value_operations.ownHandle(at.isolate, at.context(), value) catch |err| protocolError(err),
    };
}

/// A platform object's wrapper in its RELEVANT realm (`instance.ctx`) - the
/// design's relevant-realm rule - whichever realm the operation entered: a
/// platform object has one wrapper, made in the realm it was created in, so
/// an object of realm A handed back through an operation entered in realm B
/// is A's wrapper, with A's prototypes - as `iframe.contentDocument` is the
/// frame's document, not a second one of the parent's. OWNED (a Global of the
/// caller's own; the wrapper cache keeps its own).
///
/// The wrapper is looked up or made with the relevant realm entered, since
/// the wrapper cache and the templates are per realm. A platform object whose
/// realm the engine no longer hosts - retired (its engine context cleared),
/// or a host's context with none - has no realm left to be wrapped in but the
/// one the operation is in, so it is wrapped there. One of another agent is
/// not this agent's to wrap.
pub fn relevantWrapper(isolate: *ffi.Isolate, instance: *engine.Instance) Error!*ffi.Value {
    const relevant = instance.ctx;
    const home: ?Entered = if (relevant.engine_ctx != null) blk: {
        if (realm_entry.agentOf(relevant) != isolate) return error.OperationFailed;
        break :blk realm_entry.enter(relevant) catch null;
    } else null;
    defer if (home) |h| h.leave();
    // The wrapper cache's Global, BORROWED - or, when the object cannot be
    // wrapped (no template for its interface), a new undefined, OWNED: a
    // wrapper is never undefined, so that answer is this call's to keep.
    const wrapper = conversions.instanceToV8(isolate, instance);
    if (ffi.v8_Value_IsUndefined(wrapper)) return wrapper;
    return ffi.v8_Global_Clone(wrapper) orelse error.OperationFailed;
}

/// `value` with a platform object replaced by its wrapper in its relevant
/// realm, BORROWED from the Global this holds until `release` - for handing a
/// value to an adapter function that would wrap it wherever it is called.
pub const Relevant = struct {
    value: engine.JSValue,
    held: ?*ffi.Value = null,

    pub fn of(isolate: *ffi.Isolate, value: engine.JSValue) Error!Relevant {
        return switch (value) {
            .instance => |instance| blk: {
                const wrapper = try relevantWrapper(isolate, instance);
                break :blk .{ .value = borrowed(wrapper), .held = wrapper };
            },
            else => .{ .value = value },
        };
    }

    pub fn release(self: Relevant) void {
        if (self.held) |held| ffi.v8_Global_Dispose(held);
    }
};

/// A list of values as `Relevant` does one: the list itself when it holds no
/// platform object, else a copy with each replaced. `release` ends both.
pub const RelevantList = struct {
    values: []const engine.JSValue,
    copy: ?[]Relevant = null,
    copied: ?[]engine.JSValue = null,

    const allocator = std.heap.c_allocator;

    pub fn of(isolate: *ffi.Isolate, values: []const engine.JSValue) Error!RelevantList {
        for (values) |value| {
            if (value == .instance) break;
        } else return .{ .values = values };
        const copy = allocator.alloc(Relevant, values.len) catch return error.OutOfMemory;
        errdefer allocator.free(copy);
        const copied = allocator.alloc(engine.JSValue, values.len) catch return error.OutOfMemory;
        errdefer allocator.free(copied);
        var made: usize = 0;
        errdefer for (copy[0..made]) |relevant| relevant.release();
        for (values, copy, copied) |value, *slot, *out| {
            slot.* = try Relevant.of(isolate, value);
            out.* = slot.value;
            made += 1;
        }
        return .{ .values = copied, .copy = copy, .copied = copied };
    }

    pub fn release(self: RelevantList) void {
        const copy = self.copy orelse return;
        for (copy) |relevant| relevant.release();
        allocator.free(copy);
        allocator.free(self.copied.?);
    }
};

/// An OWNED protocol value over a Global the FFI made.
pub fn owned(global: *ffi.Value) engine.Owned {
    return .{ .value = realm_entry.owned(global) };
}

/// A JSValue BORROWING a Global for a call.
pub fn borrowed(global: *ffi.Value) engine.JSValue {
    return .{ .handle = .{ .ptr = global } };
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
pub fn throwTypeError(at: anytype, message: []const u8) Error {
    const exception = try newTypeError(at.isolate, at.context(), message);
    return rethrow(at.isolate, exception);
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
pub fn getSymbolMethod(at: anytype, object: *ffi.Value, which: enum { iterator, async_iterator }) Error!?*ffi.Value {
    const isolate = at.isolate;
    const symbol = switch (which) {
        .iterator => ffi.v8_Symbol_GetIterator(isolate),
        .async_iterator => ffi.v8_Symbol_GetAsyncIterator(isolate),
    } orelse return error.OperationFailed;
    defer ffi.v8_Symbol_Dispose(symbol);
    // 1. Let func be ? GetV(V, P).
    const func = ffi.v8_Object_GetPropertyWithSymbol(at.context(), @ptrCast(object), symbol) orelse
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
pub fn get(at: anytype, object: *ffi.Value, key: []const u8) Error!*ffi.Value {
    var threw = false;
    const result = ffi.v8_Object_GetCatching(at.context(), object, key.ptr, @intCast(key.len), &threw);
    if (threw) return rethrow(at.isolate, result);
    return result orelse error.OperationFailed;
}

/// Call(F, V, args), rethrowing what it throws. OWNED. An ECMAScript Call
/// the engine makes (the iterator protocol), not "invoke a callback
/// function": no microtask checkpoint follows it.
pub fn call(at: anytype, function: *ffi.Value, receiver: ?*ffi.Value, args: []const *ffi.Value) Error!*ffi.Value {
    var threw = false;
    const result = ffi.v8_Function_CallCatchingNativeStep(at.context(), function, receiver, @intCast(args.len), if (args.len == 0) null else args.ptr, &threw);
    if (threw) return rethrow(at.isolate, result);
    return result orelse error.OperationFailed;
}

/// ToBoolean(V).
pub fn toBoolean(at: anytype, value: *ffi.Value) bool {
    return ffi.v8_Value_BooleanValue(value, at.isolate);
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
pub fn iteratorResultObject(at: anytype, value: *ffi.Value, done: bool) Error!*ffi.Value {
    const isolate = at.isolate;
    const context = at.context();
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

// ============================================================================
// Native closures, completions and promises
// ============================================================================

/// Where engine work happens inside a native closure V8 called: its isolate,
/// and the closure's own context, which V8 entered for the call. Has what
/// the helpers here read of an Entered realm.
pub const Here = struct {
    isolate: *ffi.Isolate,
    /// OWNED.
    current: *ffi.Context,

    pub fn ofCall(info: *const ffi.FunctionCallbackInfo) ?Here {
        const isolate = info.getIsolate();
        const current = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return null;
        return .{ .isolate = isolate, .current = current };
    }

    pub fn context(self: Here) *ffi.Context {
        return self.current;
    }

    pub fn deinit(self: Here) void {
        ffi.v8_Context_Dispose(self.current);
    }
};

/// ECMAScript CreateBuiltinFunction(steps, length, "", « ») in the realm `at`
/// is in: a native closure over `data` (BORROWED - the function keeps its
/// own). Function::New, so it is collected with what references it. OWNED.
pub fn newClosure(at: anytype, steps: ffi.FunctionCallback, data: ?*ffi.Value, length: c_int) Error!*ffi.Value {
    return ffi.v8_Function_NewWithData(at.context(), steps, data, length) orelse error.OperationFailed;
}

/// A native closure's [[data]]. OWNED.
pub fn closureData(info: *const ffi.FunctionCallbackInfo) *ffi.Value {
    return info.getData();
}

/// A native closure's argument `index` (undefined past the last). OWNED.
pub fn closureArgument(info: *const ffi.FunctionCallbackInfo, index: c_int) *ffi.Value {
    return info.get(index);
}

/// Return `value` from a native closure. Takes it.
pub fn closureReturn(info: *const ffi.FunctionCallbackInfo, value: *ffi.Value) void {
    defer ffi.v8_Global_Dispose(value);
    ffi.FunctionCallbackInfo.v8_FunctionCallbackInfo_SetReturnValueGlobal(info, value);
}

/// Throw `value` from a native closure. Takes it.
pub fn closureThrow(isolate: *ffi.Isolate, value: *ffi.Value) void {
    defer ffi.v8_Global_Dispose(value);
    ffi.v8_Isolate_ThrowException(isolate, value);
}

/// ECMAScript's Completion of an operation that can throw: the value, or
/// what was thrown. OWNED either way.
pub const Caught = union(enum) {
    normal: *ffi.Value,
    thrown: *ffi.Value,

    pub fn release(self: Caught) void {
        switch (self) {
            inline else => |value| ffi.v8_Global_Dispose(value),
        }
    }
};

/// Completion(Get(O, P)) for a string key.
pub fn getCaught(at: anytype, object: *ffi.Value, key: []const u8) Error!Caught {
    var threw = false;
    const result = ffi.v8_Object_GetCatching(at.context(), object, key.ptr, @intCast(key.len), &threw);
    const value = result orelse return error.OperationFailed;
    return if (threw) .{ .thrown = value } else .{ .normal = value };
}

/// Completion(Call(F, V, args)); a non-callable F is a TypeError thrown. The
/// iterator protocol's Call, like `call`: no microtask checkpoint follows it.
pub fn callCaught(at: anytype, function: *ffi.Value, receiver: ?*ffi.Value, args: []const *ffi.Value) Error!Caught {
    if (!ffi.v8_Value_IsFunction(function)) return .{ .thrown = try newTypeError(at.isolate, at.context(), "not a function") };
    var threw = false;
    const result = ffi.v8_Function_CallCatchingNativeStep(at.context(), function, receiver, @intCast(args.len), if (args.len == 0) null else args.ptr, &threw);
    const value = result orelse return error.OperationFailed;
    return if (threw) .{ .thrown = value } else .{ .normal = value };
}

/// A new promise of the realm `at` is in, resolved with `value` - the
/// resolve function's semantics, so a thenable is adopted. OWNED.
pub fn promiseResolvedWith(at: anytype, value: *ffi.Value) Error!*ffi.Value {
    return settled(at, value, true);
}

/// A new promise of the realm `at` is in, rejected with `reason`. OWNED.
pub fn promiseRejectedWith(at: anytype, reason: *ffi.Value) Error!*ffi.Value {
    return settled(at, reason, false);
}

fn settled(at: anytype, value: *ffi.Value, fulfilled: bool) Error!*ffi.Value {
    const context = at.context();
    const resolver = ffi.v8_PromiseResolver_New(context) orelse return error.OperationFailed;
    defer ffi.v8_PromiseResolver_Dispose(resolver);
    const promise = ffi.v8_PromiseResolver_GetPromise(resolver) orelse return error.OperationFailed;
    errdefer ffi.v8_Promise_Dispose(promise);
    const ok = if (fulfilled) ffi.v8_PromiseResolver_Resolve(resolver, context, value) else ffi.v8_PromiseResolver_Reject(resolver, context, value);
    if (!ok) return error.OperationFailed;
    return @ptrCast(promise);
}

/// A promise rejected with a new TypeError of the realm `at` is in. OWNED.
pub fn promiseRejectedWithTypeError(at: anytype, message: []const u8) Error!*ffi.Value {
    const reason = try newTypeError(at.isolate, at.context(), message);
    defer ffi.v8_Global_Dispose(reason);
    return promiseRejectedWith(at, reason);
}

/// PerformPromiseThen(promise, onFulfilled, onRejected, capability) - a null
/// handler is undefined - the capability being V8's derived promise: NewPromiseCapability of the
/// promise's species constructor - %Promise% for the promises made here,
/// unless script replaced Promise[@@species]. OWNED.
pub fn then(at: anytype, promise: *ffi.Value, on_fulfilled: ?*ffi.Value, on_rejected: ?*ffi.Value) Error!*ffi.Value {
    return ffi.v8_Promise_ThenWithOptionalHandlers(at.context(), promise, on_fulfilled, on_rejected) orelse error.OperationFailed;
}

/// ECMAScript PromiseResolve(%Promise%, x) - its Completion.
///
/// Step 1.b compares x.constructor with %Promise% as %Promise.prototype%'s
/// "constructor" names it: the embedder API reaches no intrinsic %Promise%,
/// and the two differ only once script has replaced that property.
pub fn promiseResolve(at: anytype, value: *ffi.Value) Error!Caught {
    // 1. If IsPromise(x) is true, then
    if (ffi.v8_Value_IsPromise(value)) {
        // a. Let xConstructor be ? Get(x, "constructor").
        const x_constructor = switch (try getCaught(at, value, "constructor")) {
            .thrown => |thrown| return .{ .thrown = thrown },
            .normal => |v| v,
        };
        defer ffi.v8_Global_Dispose(x_constructor);
        // b. If SameValue(xConstructor, C) is true, return x.
        if (try isPromiseConstructor(at, x_constructor)) {
            return .{ .normal = ffi.v8_Global_Clone(value) orelse return error.OperationFailed };
        }
    }
    // 2. Let promiseCapability be ? NewPromiseCapability(C).
    // 3. Perform ? Call(promiseCapability.[[Resolve]], undefined, « x »).
    // 4. Return promiseCapability.[[Promise]].
    return .{ .normal = try promiseResolvedWith(at, value) };
}

/// Whether `candidate` is %Promise% (see promiseResolve). The promise whose
/// [[Prototype]] is read is a pending one nothing resolves: resolving it
/// with `candidate` would Get(candidate, "then") - a step PromiseResolve
/// does not take, which script could observe.
fn isPromiseConstructor(at: anytype, candidate: *ffi.Value) Error!bool {
    const resolver = ffi.v8_PromiseResolver_New(at.context()) orelse return error.OperationFailed;
    defer ffi.v8_PromiseResolver_Dispose(resolver);
    const pending = ffi.v8_PromiseResolver_GetPromise(resolver) orelse return error.OperationFailed;
    defer ffi.v8_Promise_Dispose(pending);
    const prototype = ffi.v8_Object_GetPrototypeV2(@ptrCast(pending)) orelse return error.OperationFailed;
    defer ffi.v8_Global_Dispose(prototype);
    const intrinsic = switch (try getCaught(at, prototype, "constructor")) {
        .normal => |v| v,
        .thrown => |thrown| {
            ffi.v8_Global_Dispose(thrown);
            return false;
        },
    };
    defer ffi.v8_Global_Dispose(intrinsic);
    return ffi.v8_Value_StrictEquals(candidate, intrinsic);
}

/// %AsyncIteratorPrototype% of the realm `at` is in: the [[Prototype]] of
/// %AsyncGeneratorPrototype%, reached from an async generator function the
/// realm evaluates (the embedder API names no such intrinsic). Microtasks
/// are held off for it, so no checkpoint runs here. OWNED.
pub fn asyncIteratorPrototype(at: anytype) Error!*ffi.Value {
    var body: struct {
        isolate: *ffi.Isolate,
        context: *ffi.Context,
        result: ?*ffi.Value = null,
        pub fn run(self: *@This()) void {
            const code = "(async function* () {}).prototype";
            const text = ffi.v8_String_NewFromUtf8(self.isolate, code.ptr, code.len) orelse return;
            defer ffi.v8_String_Dispose(text);
            const script = ffi.v8_Script_Compile(self.context, text) orelse return;
            defer ffi.v8_Script_Dispose(script);
            self.result = ffi.v8_Script_Run(self.context, script);
        }
        fn call(data: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.run();
        }
    } = .{ .isolate = at.isolate, .context = at.context() };
    ffi.v8_RunWithMicrotasksSuppressed(at.isolate, @TypeOf(body).call, &body);
    // The generator function's prototype: an object whose [[Prototype]] is
    // %AsyncGeneratorPrototype%, whose [[Prototype]] is
    // %AsyncIteratorPrototype%.
    const generator_prototype = body.result orelse return error.OperationFailed;
    defer ffi.v8_Global_Dispose(generator_prototype);
    const async_generator_prototype = ffi.v8_Object_GetPrototypeV2(@ptrCast(generator_prototype)) orelse return error.OperationFailed;
    defer ffi.v8_Global_Dispose(async_generator_prototype);
    return ffi.v8_Object_GetPrototypeV2(@ptrCast(async_generator_prototype)) orelse error.OperationFailed;
}
