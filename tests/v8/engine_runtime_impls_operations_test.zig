//! The runtime-impls lane's Engine operations, as V8 implements them:
//! createObservableArray, queueMicrotask, createResolvedPromise,
//! createRejectedPromise, createSimpleException and createDictionaryObject.
//!
//! Impls reach script values through these instead of V8 (AGENTS.md, "The
//! engine boundary"): each takes the realm as a runtime.Context and hands back
//! an OWNED handle, or an ENGINE-OWNED one where its declaration says so.
//!
//! At the end, the engine protocol's first operations bound to V8
//! (`@import("engine")`): the same adapter functions, statically dispatched.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const engine = &v8.engine.v8_engine_interface;

/// A live isolate with an entered context and a runtime realm over it, one for
/// the whole file, as in engine_realm_operations_test.zig - V8 is never torn
/// down here. Microtasks are explicit, as the browser runs them.
var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var data_once: ?*runtime.ContextData = null;

fn realm() !runtime.Context {
    if (data_once) |d| return d;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    ffi.v8_Isolate_SetMicrotasksPolicy(i, @intFromEnum(ffi.MicrotasksPolicy.Explicit));
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    const r = try runtime.Realm.init(std.heap.page_allocator, .{ .v8_context = context, .isolate = i });
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{
        .engine = engine,
        .engine_ctx = context,
        .realm = r,
    });
    isolate_once = i;
    context_once = context;
    data_once = data;
    return data;
}

/// Script's answer to `expression`, as an integer.
fn eval(expression: []const u8) !i32 {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, expression.ptr, @intCast(expression.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context);
}

/// Put `value` (a handle) where script can see it, as `globalThis[name]`.
fn expose(name: []const u8, value: runtime.JSValue) !void {
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(@alignCast(value.handle.ptr)))) return error.SetFailed;
}

test "a simple exception is the realm's own TypeError, RangeError or ReferenceError, and owned" {
    const ctx = try realm();
    const type_error = try engine.createSimpleException.?(ctx, .TypeError, "bad argument");
    defer engine.releaseValue.?(type_error);
    try std.testing.expect(type_error.handle.needs_disposal);
    try expose("typeError", type_error);
    try std.testing.expectEqual(@as(i32, 1), try eval("typeError instanceof TypeError && typeError.message === 'bad argument' ? 1 : 0"));

    const range_error = try engine.createSimpleException.?(ctx, .RangeError, "");
    defer engine.releaseValue.?(range_error);
    try expose("rangeError", range_error);
    try std.testing.expectEqual(@as(i32, 1), try eval("rangeError instanceof RangeError && rangeError.message === '' ? 1 : 0"));

    // Replacing the global does not change which constructor makes it: the
    // spec's constructor is the realm's intrinsic.
    try std.testing.expectEqual(@as(i32, 1), try eval("globalThis.SavedTypeError = TypeError; globalThis.TypeError = function Fake() {}; 1"));
    const intrinsic = try engine.createSimpleException.?(ctx, .TypeError, "x");
    defer engine.releaseValue.?(intrinsic);
    try expose("intrinsic", intrinsic);
    try std.testing.expectEqual(@as(i32, 1), try eval("const ok = intrinsic instanceof SavedTypeError ? 1 : 0; globalThis.TypeError = SavedTypeError; ok"));

    const reference_error = try engine.createSimpleException.?(ctx, .ReferenceError, "gone");
    defer engine.releaseValue.?(reference_error);
    try expose("referenceError", reference_error);
    try std.testing.expectEqual(@as(i32, 1), try eval("referenceError instanceof ReferenceError && referenceError.message === 'gone' ? 1 : 0"));

    // No intrinsic reachable through V8's embedder API: said, not faked.
    try std.testing.expectError(error.NotSupported, engine.createSimpleException.?(ctx, .URIError, "x"));
    try std.testing.expectError(error.NotSupported, engine.createSimpleException.?(ctx, .EvalError, "x"));
}

test "a dictionary is an ordinary object with its members in the order given" {
    const ctx = try realm();
    const members = [_]runtime.DictionaryMember{
        .{ .name = "name", .value = runtime.JSValue.fromStringRef("sid") },
        .{ .name = "value", .value = runtime.JSValue.fromStringRef("") },
        .{ .name = "secure", .value = runtime.JSValue.fromBoolean(true) },
        .{ .name = "expires", .value = runtime.JSValue.jsNull },
    };
    const dict = try engine.createDictionaryObject.?(ctx, &members);
    defer engine.releaseValue.?(dict);
    try std.testing.expect(dict.handle.needs_disposal);
    try expose("dict", dict);
    try std.testing.expectEqual(@as(i32, 1), try eval(
        \\Object.getPrototypeOf(dict) === Object.prototype &&
        \\Object.keys(dict).join() === "name,value,secure,expires" &&
        \\dict.name === "sid" && dict.value === "" && dict.secure === true && dict.expires === null ? 1 : 0
    ));

    // A member that is itself a handle is borrowed, not consumed.
    const inner = try engine.createDictionaryObject.?(ctx, &.{.{ .name = "a", .value = runtime.JSValue.fromNumber(1) }});
    defer engine.releaseValue.?(inner);
    const outer = try engine.createDictionaryObject.?(ctx, &.{.{ .name = "inner", .value = inner }});
    defer engine.releaseValue.?(outer);
    try expose("outer", outer);
    try std.testing.expectEqual(@as(i32, 1), try eval("outer.inner.a === 1 ? 1 : 0"));

    const empty = try engine.createDictionaryObject.?(ctx, &.{});
    defer engine.releaseValue.?(empty);
    try expose("empty", empty);
    try std.testing.expectEqual(@as(i32, 0), try eval("Object.keys(empty).length"));
}

test "a promise resolved with, and rejected with, a value" {
    const ctx = try realm();
    const resolved = try engine.createResolvedPromise.?(ctx, runtime.JSValue.fromNumber(42));
    defer engine.releaseValue.?(resolved);
    const promise: *ffi.Promise = @ptrCast(@alignCast(resolved.handle.ptr));
    try std.testing.expectEqual(@as(c_int, 1), ffi.v8_Promise_State(promise));
    const result = ffi.v8_Promise_Result(promise) orelse return error.NoResult;
    defer ffi.v8_Value_Dispose(result);
    try std.testing.expectEqual(@as(i32, 42), ffi.v8_Value_Int32Value(result, context_once.?));

    const reason = try engine.createSimpleException.?(ctx, .TypeError, "no");
    defer engine.releaseValue.?(reason);
    const rejected = try engine.createRejectedPromise.?(ctx, reason);
    defer engine.releaseValue.?(rejected);
    try expose("rejected", rejected);
    try std.testing.expectEqual(@as(c_int, 2), ffi.v8_Promise_State(@ptrCast(@alignCast(rejected.handle.ptr))));

    // Script sees the reason itself once the reactions run.
    try std.testing.expectEqual(@as(i32, 1), try eval("globalThis.caught = 0; rejected.catch((e) => { globalThis.caught = e instanceof TypeError && e.message === 'no' ? 1 : 2; }); 1"));
    try engine.performMicrotaskCheckpoint.?(ctx);
    try std.testing.expectEqual(@as(i32, 1), try eval("globalThis.caught"));
}

const Ran = struct {
    count: usize = 0,
    /// How many of script's microtasks had run when these steps did.
    script_before: i32 = -1,

    fn steps(data: ?*anyopaque) void {
        const self: *Ran = @ptrCast(@alignCast(data.?));
        self.count += 1;
        self.script_before = eval("order.length") catch -2;
    }
};

test "a queued microtask runs at the next checkpoint, once, after those queued before it" {
    const ctx = try realm();
    var ran: Ran = .{};
    try std.testing.expectEqual(@as(i32, 1), try eval("globalThis.order = []; Promise.resolve().then(() => order.push('script')); 1"));
    try engine.queueMicrotask.?(ctx, Ran.steps, &ran);
    try std.testing.expectEqual(@as(usize, 0), ran.count);
    try engine.performMicrotaskCheckpoint.?(ctx);
    try std.testing.expectEqual(@as(usize, 1), ran.count);
    try std.testing.expectEqual(@as(i32, 1), ran.script_before);
    try engine.performMicrotaskCheckpoint.?(ctx);
    try std.testing.expectEqual(@as(usize, 1), ran.count);
}

test "an observable array is an Array to script, and the engine's to keep" {
    const ctx = try realm();
    const array = try engine.createObservableArray.?(ctx);
    // ENGINE-OWNED: never released here.
    try expose("observed", array);
    try std.testing.expectEqual(@as(i32, 1), try eval("Array.isArray(observed) && observed.length === 0 ? 1 : 0"));
    try std.testing.expectEqual(@as(i32, 1), try eval("Object.getPrototypeOf(observed) === Array.prototype ? 1 : 0"));
    try std.testing.expectEqual(@as(i32, 1), try eval("observed[0] = 'a'; observed[1] = 'b'; observed.length === 2 && observed[1] === 'b' ? 1 : 0"));
    // The backing list admits no holes: an index past the end is refused.
    try std.testing.expectEqual(@as(i32, 1), try eval("Reflect.set(observed, 5, 'x') === false && observed.length === 2 ? 1 : 0"));

    // The same object each time script reads the same handle.
    try expose("again", array);
    try std.testing.expectEqual(@as(i32, 1), try eval("again === observed ? 1 : 0"));
}

test "a realm without an engine reports it rather than making nothing" {
    var bare = try runtime.ContextData.init(std.testing.allocator, .{});
    defer bare.deinit();
    try std.testing.expectError(error.NoEngine, runtime.ObservableArrayExotic.create(&bare));
}

test "the current realm is the one the context manager hosts for the entered context" {
    _ = try realm();
    // A context no manager hosts is no realm the engine knows.
    try std.testing.expect(engine.currentRealm.?() == null);

    // Already initialized is as good: the manager is per thread.
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const hosted = try v8.context_manager.getOrCreate(context_once.?, std.heap.page_allocator);
    const current = engine.currentRealm.?() orelse return error.NoCurrentRealm;
    try std.testing.expectEqual(hosted, current);
}

/// A handle to what script's `expression` evaluates to. OWNED by the caller
/// (a Global the FFI made): dispose it with v8_Value_Dispose.
fn evalHandle(expression: []const u8) !*ffi.Value {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, expression.ptr, @intCast(expression.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

test "an ArrayBufferView is described by type, offset and length, and anything else is not one" {
    _ = try realm();
    const view = try evalHandle("globalThis.bytes = new Uint8Array(new ArrayBuffer(8), 2, 4); bytes");
    defer ffi.v8_Value_Dispose(view);
    const described = engine.describeArrayBufferView.?(try argument(view)) orelse return error.NotAView;
    try std.testing.expectEqual(runtime.arraybuffer_view.ViewType.uint8_array, described.view_type);
    try std.testing.expectEqual(@as(usize, 2), described.byte_offset);
    try std.testing.expectEqual(@as(usize, 4), described.byte_length);
    try std.testing.expect(!described.detached and !described.shared);

    const data_view = try evalHandle("new DataView(new ArrayBuffer(3))");
    defer ffi.v8_Value_Dispose(data_view);
    try std.testing.expectEqual(runtime.arraybuffer_view.ViewType.data_view, engine.describeArrayBufferView.?(try argument(data_view)).?.view_type);

    const plain = try evalHandle("({ length: 4 })");
    defer ffi.v8_Value_Dispose(plain);
    try std.testing.expect(engine.describeArrayBufferView.?(try argument(plain)) == null);
    try std.testing.expect(engine.describeArrayBufferView.?(runtime.JSValue.fromNumber(1)) == null);
}

test "bytes are written into a view from its offset, and never past its end" {
    _ = try realm();
    const view = try evalHandle("globalThis.target = new Uint8Array(new ArrayBuffer(8), 2, 4); target");
    defer ffi.v8_Value_Dispose(view);
    const value = try argument(view);
    try engine.writeIntoArrayBufferView.?(value, "ab", 1);
    try std.testing.expectEqual(@as(i32, 1), try eval("const all = new Uint8Array(target.buffer); all[3] === 97 && all[4] === 98 && all[2] === 0 && all[5] === 0 ? 1 : 0"));

    // The spec asserts the bytes fit; a caller that did not check is told.
    try std.testing.expectError(error.OperationFailed, engine.writeIntoArrayBufferView.?(value, "abcd", 1));
    try std.testing.expectError(error.TypeError, engine.writeIntoArrayBufferView.?(runtime.JSValue.fromNumber(1), "a", 0));
    // Nothing to write is always a success.
    try engine.writeIntoArrayBufferView.?(value, "", 4);
}

/// `value` as the binding hands an impl an `any` argument: primitives
/// classified, an object as a borrowed handle (a Global tagged `.local`).
/// A string argument is copied: free it with `JSValue.deinit`.
fn argument(value: *ffi.Value) !runtime.JSValue {
    return v8.conversions.fromV8Value(runtime.JSValue, std.testing.allocator, isolate_once.?, context_once.?, value);
}

/// Run `steps(data)` under a TryCatch: the exception it left in flight, if
/// any (a Global the caller disposes), now caught.
fn catching(steps: *const fn (?*anyopaque) callconv(.c) void, data: ?*anyopaque) !?*ffi.Value {
    var exception: ?*ffi.Value = null;
    _ = ffi.v8_RunCatching(isolate_once.?, steps, data, &exception);
    return exception;
}

const Call = struct {
    callback: *runtime.CallbackWrapper,
    result: anyerror!runtime.JSValue = error.NotCalled,

    fn run(data: ?*anyopaque) callconv(.c) void {
        const self: *Call = @ptrCast(@alignCast(data.?));
        self.result = engine.callUserObjectOperation.?(data_once.?, self.callback, "acceptNode", &.{runtime.JSValue.fromNumber(5)});
    }
};

/// A callback interface value made of script's `expression`, as the binding
/// converts one. The wrapper takes the value's handle: its deinit releases it.
fn callbackOf(expression: []const u8) !runtime.CallbackWrapper {
    const value = try evalHandle(expression);
    return (try runtime.CallbackWrapper.init(engine, context_once.?, value, "acceptNode", std.testing.allocator)) orelse {
        ffi.v8_Value_Dispose(value);
        return error.NotCallable;
    };
}

test "a callback interface value is called as a function, or through its operation, and what it throws stays in flight" {
    const ctx = try realm();

    // A function: called with undefined as this and the arguments given.
    var function = try callbackOf("(function (n) { 'use strict'; return this === undefined ? n + 1 : -1; })");
    defer function.deinit();
    var call: Call = .{ .callback = &function };
    try std.testing.expect(try catching(Call.run, &call) == null);
    const result = try call.result;
    defer engine.releaseValue.?(result);
    try std.testing.expectEqual(@as(f64, 6), try engine.convertToUnrestrictedDouble.?(ctx, result));

    // An object: its operation looked up at the call, with it as this.
    var object = try callbackOf("({ base: 10, acceptNode(n) { return this.base + n; } })");
    defer object.deinit();
    call = .{ .callback = &object };
    try std.testing.expect(try catching(Call.run, &call) == null);
    const from_object = try call.result;
    defer engine.releaseValue.?(from_object);
    try std.testing.expectEqual(@as(f64, 15), try engine.convertToUnrestrictedDouble.?(ctx, from_object));

    // "rethrow": the call's exception is the caller's, in flight.
    var throwing = try callbackOf("(function () { throw new RangeError('filtered'); })");
    defer throwing.deinit();
    call = .{ .callback = &throwing };
    const thrown = (try catching(Call.run, &call)) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(thrown);
    try std.testing.expectError(error.ExceptionPending, call.result);
    try expose("rethrown", .{ .handle = .{ .ptr = thrown, .needs_disposal = false } });
    try std.testing.expectEqual(@as(i32, 1), try eval("rethrown instanceof RangeError && rethrown.message === 'filtered' ? 1 : 0"));

    // WebIDL § 3.12 step 10.2: Get(O, opName) is rethrown - a getter that
    // throws is the call's exception.
    var throwing_getter = try callbackOf("({ get acceptNode() { throw new SyntaxError('getter'); } })");
    defer throwing_getter.deinit();
    call = .{ .callback = &throwing_getter };
    const from_getter = (try catching(Call.run, &call)) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(from_getter);
    try std.testing.expectError(error.ExceptionPending, call.result);
    try expose("fromGetter", .{ .handle = .{ .ptr = from_getter, .needs_disposal = false } });
    try std.testing.expectEqual(@as(i32, 1), try eval("fromGetter instanceof SyntaxError && fromGetter.message === 'getter' ? 1 : 0"));

    // Step 10.3: no such property - undefined is not callable - is a TypeError.
    var no_operation = try callbackOf("({})");
    defer no_operation.deinit();
    call = .{ .callback = &no_operation };
    const missing = (try catching(Call.run, &call)) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(missing);
    try std.testing.expectError(error.ExceptionPending, call.result);
    try expose("missing", .{ .handle = .{ .ptr = missing, .needs_disposal = false } });
    try std.testing.expectEqual(@as(i32, 1), try eval("missing instanceof TypeError ? 1 : 0"));

    // Step 10.3 again: a property that is not callable is a TypeError too.
    var not_callable = try callbackOf("({ acceptNode: 3 })");
    defer not_callable.deinit();
    call = .{ .callback = &not_callable };
    const type_error = (try catching(Call.run, &call)) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(type_error);
    try std.testing.expectError(error.ExceptionPending, call.result);
    try expose("notCallable", .{ .handle = .{ .ptr = type_error, .needs_disposal = false } });
    try std.testing.expectEqual(@as(i32, 1), try eval("notCallable instanceof TypeError ? 1 : 0"));
}

const ToNumber = struct {
    value: runtime.JSValue,
    result: anyerror!f64 = error.NotCalled,

    fn run(data: ?*anyopaque) callconv(.c) void {
        const self: *ToNumber = @ptrCast(@alignCast(data.?));
        self.result = engine.convertToUnrestrictedDouble.?(data_once.?, self.value);
    }
};

test "convert to unrestricted double is ToNumber, and what it throws stays in flight" {
    const ctx = try realm();
    try std.testing.expectEqual(@as(f64, 2.5), try engine.convertToUnrestrictedDouble.?(ctx, runtime.JSValue.fromNumber(2.5)));
    try std.testing.expectEqual(@as(f64, 1), try engine.convertToUnrestrictedDouble.?(ctx, runtime.JSValue.fromBoolean(true)));
    try std.testing.expectEqual(@as(f64, 0), try engine.convertToUnrestrictedDouble.?(ctx, runtime.JSValue.jsNull));
    try std.testing.expect(std.math.isNan(try engine.convertToUnrestrictedDouble.?(ctx, runtime.JSValue.jsUndefined)));
    try std.testing.expectEqual(@as(f64, 42), try engine.convertToUnrestrictedDouble.?(ctx, runtime.JSValue.fromStringRef(" 42 ")));
    try std.testing.expectEqual(@as(f64, 255), try engine.convertToUnrestrictedDouble.?(ctx, runtime.JSValue.fromStringRef("0xff")));

    const object = try evalHandle("({ valueOf() { return 7; } })");
    defer ffi.v8_Value_Dispose(object);
    try std.testing.expectEqual(@as(f64, 7), try engine.convertToUnrestrictedDouble.?(ctx, try argument(object)));

    const symbol = try evalHandle("Symbol('s')");
    defer ffi.v8_Value_Dispose(symbol);
    var to_number: ToNumber = .{ .value = try argument(symbol) };
    const thrown = (try catching(ToNumber.run, &to_number)) orelse return error.NothingThrown;
    defer ffi.v8_Global_Dispose(thrown);
    try std.testing.expectError(error.ExceptionPending, to_number.result);
    try expose("symbolError", .{ .handle = .{ .ptr = thrown, .needs_disposal = false } });
    try std.testing.expectEqual(@as(i32, 1), try eval("symbolError instanceof TypeError ? 1 : 0"));
}

test "a callback-function argument is handed over as an owned handle to the same function" {
    _ = try realm();
    // What the conversion hands an impl for a callback-function argument: a
    // Global it made, tagged `.global_handle`.
    const function = try evalHandle("globalThis.theCallback = function () { return 7; }; theCallback");
    const tagged = v8.pointer_tag.tagPointer(@ptrCast(function), .global_handle);

    const taken = engine.takeCallbackFunction.?(tagged);
    try std.testing.expect(taken == .handle);
    try std.testing.expect(taken.handle.needs_disposal);
    try std.testing.expectEqual(@intFromPtr(function), @intFromPtr(taken.handle.ptr));
    try expose("taken", taken);
    try std.testing.expectEqual(@as(i32, 1), try eval("taken === theCallback ? 1 : 0"));
    // The impl's to release; after that the function is script's alone.
    engine.releaseValue.?(taken);
    try std.testing.expectEqual(@as(i32, 7), try eval("theCallback()"));
}

// ============================================================================
// The same adapter functions, through the engine protocol
// ============================================================================
//
// `@import("engine")` bound to V8 (src/runtime/engines/v8/protocol.zig): each
// `protocol.op(...)` is a direct call into the adapter function the table
// above also names - both paths reach the same code. Imported under another
// name only because this file already calls the table `engine`: a file that
// moves to the protocol changes every call and takes the name.
//
// Here rather than in a file of their own: every tests/v8 file is a root
// compile of most of the tree (6-9 GB), and these need no setup the file
// does not already have.

const protocol = @import("engine");

/// What script's `expression` evaluates to, as an Owned handle.
fn evalOwned(expression: []const u8) !protocol.Owned {
    return .{ .value = .{ .handle = .{ .ptr = try evalHandle(expression), .needs_disposal = true } } };
}

test "the protocol is bound to V8, which has every capability the protocol declares" {
    try std.testing.expectEqualStrings("V8", protocol.name);
    inline for (@typeInfo(protocol.Capabilities).@"struct".fields) |field| {
        try std.testing.expect(@field(protocol.capabilities, field.name));
    }
}

test "protocol: currentRealm is the context manager's realm for the entered context, and holds no context" {
    _ = try realm();
    // Already initialized, and already hosted, are as good.
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const hosted = try v8.context_manager.getOrCreate(context_once.?, std.heap.page_allocator);
    const contexts_before = ffi.v8_Debug_LiveContextGlobals();
    try std.testing.expectEqual(hosted, protocol.currentRealm() orelse return error.NoCurrentRealm);
    try std.testing.expectEqual(protocol.currentRealm(), engine.currentRealm.?());
    // Each call disposes the Global<Context> GetCurrentContext made.
    try std.testing.expectEqual(contexts_before, ffi.v8_Debug_LiveContextGlobals());
}

test "protocol: isCallable is ECMAScript IsCallable" {
    _ = try realm();
    const function = try evalOwned("(function () {})");
    defer function.release();
    const object = try evalOwned("({})");
    defer object.release();
    try std.testing.expect(protocol.isCallable(function.value));
    try std.testing.expect(!protocol.isCallable(object.value));
    try std.testing.expect(!protocol.isCallable(runtime.JSValue.fromNumber(1)));
    try std.testing.expect(!protocol.isCallable(runtime.JSValue.jsUndefined));
}

test "protocol: createResolvedPromise is an Owned promise of the realm, fulfilled with the value" {
    const ctx = try realm();
    const resolved = try protocol.createResolvedPromise(ctx, runtime.JSValue.fromNumber(42));
    defer resolved.release();
    try std.testing.expect(resolved.value.handle.needs_disposal);
    try expose("protocolResolved", resolved.value);
    try std.testing.expectEqual(@as(i32, 1), try eval("protocolResolved instanceof Promise ? 1 : 0"));
    const promise: *ffi.Promise = @ptrCast(@alignCast(resolved.value.handle.ptr));
    try std.testing.expectEqual(@as(c_int, 1), ffi.v8_Promise_State(promise));
    const result = ffi.v8_Promise_Result(promise) orelse return error.NoResult;
    defer ffi.v8_Value_Dispose(result);
    try std.testing.expectEqual(@as(i32, 42), ffi.v8_Value_Int32Value(result, context_once.?));
}

fn setFromProtocolTask(data: ?*anyopaque) void {
    const ran: *bool = @ptrCast(@alignCast(data.?));
    const set = eval("globalThis.fromProtocolTask = 5") catch return;
    ran.* = set == 5;
}

test "protocol: runTaskInRealm runs the steps as a task inside the realm" {
    const ctx = try realm();
    var ran = false;
    try protocol.runTaskInRealm(ctx, setFromProtocolTask, &ran);
    try std.testing.expect(ran);
    try std.testing.expectEqual(@as(i32, 5), try eval("globalThis.fromProtocolTask"));
}

/// A caller of a capability-gated operation, written as every caller must be:
/// on an engine without the capability the call is compiled out.
fn handledOrUnknown(promise: runtime.JSValue) ?bool {
    if (protocol.capabilities.promise_rejection_tracking) return protocol.promiseIsHandled(promise);
    return null;
}

test "protocol: promiseIsHandled, gated on promise_rejection_tracking, is [[PromiseIsHandled]]" {
    const ctx = try realm();
    const promise = try protocol.createResolvedPromise(ctx, runtime.JSValue.jsUndefined);
    defer promise.release();
    try std.testing.expectEqual(@as(?bool, false), handledOrUnknown(promise.value));
    try expose("watched", promise.value);
    try std.testing.expectEqual(@as(i32, 1), try eval("watched.then(() => {}); 1"));
    try std.testing.expectEqual(@as(?bool, true), handledOrUnknown(promise.value));
    // Not a promise: false.
    try std.testing.expectEqual(@as(?bool, false), handledOrUnknown(runtime.JSValue.fromNumber(1)));
}

test "protocol: requestGarbageCollection collects the agent's heap" {
    _ = try realm();
    // A realm's agent is its isolate, as the context manager records it.
    const agent: *protocol.Agent = @ptrCast(isolate_once.?);
    try std.testing.expectEqual(@as(i32, 0), try eval("globalThis.collectable = new WeakRef({ big: new Array(1000).fill(1) }); 0"));
    var collected = false;
    for (0..5) |_| {
        // The target is kept alive until the job that made the WeakRef - or
        // last dereferenced it - ends (ECMAScript ClearKeptObjects, at the
        // microtask checkpoint).
        ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);
        protocol.requestGarbageCollection(agent);
        if (try eval("globalThis.collectable.deref() === undefined ? 1 : 0") == 1) {
            collected = true;
            break;
        }
    }
    try std.testing.expect(collected);
}
