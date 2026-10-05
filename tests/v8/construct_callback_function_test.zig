//! engine.constructCallbackFunction - WebIDL "construct a callback function"
//! (3.12) - as V8 implements it: IsConstructor, then Construct(F, args) in
//! F's realm with the callback's context as the incumbent, the object or the
//! throw handed back as a Completion.
//!
//! What HTML's custom elements need: "create an element" step 5.1.4 and
//! "upgrade an element" step 8 construct the definition's constructor - a
//! [[Construct]], never a [[Call]] (a class constructor called throws).

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ffi = v8.ffi;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;

/// One isolate and realm for the file, registered with the context manager
/// as a page's is; V8 is never torn down here.
fn realm() !runtime.Context {
    if (realm_once) |r| return r;
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    isolate_once = i;
    context_once = context;
    realm_once = r;
    return r;
}

fn eval(code: []const u8) !*ffi.Value {
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

fn setGlobal(name: []const u8, value: *anyopaque) !void {
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(@alignCast(value)))) return error.SetFailed;
}

/// `source`'s value as a callback function type value, as the binding would
/// hold one: retained, with the realm as its callback context. OWNED.
fn callbackOf(r: runtime.Context, source: []const u8) !engine.CallbackFunction {
    const value = try eval(source);
    defer ffi.v8_Value_Dispose(value);
    return .{ .function = try engine.retainValue(r, runtime.JSValue.fromHandle(@ptrCast(value))), .context = r };
}

/// Whether `check` holds with `owned` exposed as `globalThis[name]`.
fn holds(name: []const u8, owned: engine.Owned, check: []const u8) !bool {
    try setGlobal(name, owned.value.handle.ptr);
    return try evalInt(check) == 1;
}

test "constructs: a new object of the class, with the arguments and new.target" {
    const r = try realm();
    const point = try callbackOf(r,
        \\globalThis.Point = class Point {
        \\  constructor(x, y) { this.x = x; this.y = y; this.newTarget = new.target === Point; }
        \\}
    );
    defer point.release();
    const args = [_]runtime.JSValue{ runtime.JSValue.fromNumber(1), runtime.JSValue.fromNumber(2) };
    const completion = try engine.constructCallbackFunction(r, &point, &args);
    try std.testing.expect(completion == .normal);
    defer completion.normal.release();
    try std.testing.expect(try holds("made", completion.normal, "made instanceof Point && made.x === 1 && made.y === 2 && made.newTarget ? 1 : 0"));
}

test "an object the constructor returns is the result" {
    const r = try realm();
    const returning = try callbackOf(r, "(function Returning() { return globalThis.returned = { other: true }; })");
    defer returning.release();
    const completion = try engine.constructCallbackFunction(r, &returning, &.{});
    try std.testing.expect(completion == .normal);
    defer completion.normal.release();
    try std.testing.expect(try holds("made", completion.normal, "made === globalThis.returned ? 1 : 0"));
}

test "a throwing constructor is a throw completion of the thrown value, and nothing is left pending" {
    const r = try realm();
    const thrower = try callbackOf(r, "(class Thrower { constructor() { throw globalThis.ctorError = new Error('ctor'); } })");
    defer thrower.release();
    const completion = try engine.constructCallbackFunction(r, &thrower, &.{});
    try std.testing.expect(completion == .throw);
    defer completion.throw.release();
    try std.testing.expect(try holds("thrown", completion.throw, "thrown === globalThis.ctorError ? 1 : 0"));
    // Script runs on: nothing was left pending for it.
    try std.testing.expectEqual(@as(i32, 2), try evalInt("1 + 1"));
}

test "a non-constructor is a throw completion of a TypeError, and is never called" {
    const r = try realm();
    const sources = [_][]const u8{
        // An arrow function and a method are callable but not constructors.
        "(() => { globalThis.called = true; })",
        "({ m() { globalThis.called = true; } }).m",
        // An object that is not callable at all.
        "({})",
    };
    _ = try evalInt("globalThis.called = false, 0");
    for (sources) |source| {
        const callback = try callbackOf(r, source);
        defer callback.release();
        const completion = try engine.constructCallbackFunction(r, &callback, &.{});
        try std.testing.expect(completion == .throw);
        defer completion.throw.release();
        try std.testing.expect(try holds("thrown", completion.throw, "thrown instanceof TypeError && globalThis.called === false ? 1 : 0"));
    }
    // A primitive is no constructor either.
    const number: engine.CallbackFunction = .{ .function = .{ .value = runtime.JSValue.fromNumber(5) }, .context = r };
    const completion = try engine.constructCallbackFunction(r, &number, &.{});
    try std.testing.expect(completion == .throw);
    defer completion.throw.release();
    try std.testing.expect(try holds("thrown", completion.throw, "thrown instanceof TypeError ? 1 : 0"));
}

test "a Proxy of a class is a constructor" {
    const r = try realm();
    const proxied = try callbackOf(r, "new Proxy(class Target { constructor() { this.viaProxy = true; } }, {})");
    defer proxied.release();
    const completion = try engine.constructCallbackFunction(r, &proxied, &.{});
    try std.testing.expect(completion == .normal);
    defer completion.normal.release();
    try std.testing.expect(try holds("made", completion.normal, "made.viaProxy === true ? 1 : 0"));
}

test "constructing leaves no handle behind" {
    const r = try realm();
    const isolate = isolate_once.?;
    const point = try callbackOf(r, "(class Counted { constructor(n) { this.n = n; } })");
    defer point.release();
    const args = [_]runtime.JSValue{runtime.JSValue.fromNumber(3)};
    // Warm up, then count V8's live global handle bytes across 32 rounds.
    for (0..2) |_| {
        const c = try engine.constructCallbackFunction(r, &point, &args);
        c.normal.release();
    }
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..32) |_| {
        const c = try engine.constructCallbackFunction(r, &point, &args);
        c.normal.release();
    }
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate) <= before);
}
