//! engine.promiseResolve - ECMAScript PromiseResolve(%Promise%, x), as V8
//! implements it: x itself when IsPromise(x) and Get(x, "constructor") is the
//! realm's %Promise%; otherwise a new promise of the realm resolved with x; a
//! throw completion when that Get throws.
//!
//! What the navigation API needs (Navigation.zig invokeToPromise): Blink
//! keeps the promise an intercept() handler returns (ScriptPromise::FromV8Value
//! returns a v8::Promise as it is), and wrapping it in a new promise put two
//! extra microtask ticks before navigatesuccess. The values here are made the
//! way the binding makes a callback's return value: script objects as
//! handles, primitives as inline JSValue tags.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");

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
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context });
    data.agent = @ptrCast(i);
    isolate_once = i;
    context_once = context;
    data_once = data;
    return data;
}

fn evalIn(context: *ffi.Context, code: []const u8) !*ffi.Value {
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

fn eval(code: []const u8) !*ffi.Value {
    return evalIn(context_once.?, code);
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

fn setGlobal(name: []const u8, handle: *anyopaque) !void {
    const global = ffi.v8_Context_Global(context_once.?) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    _ = ffi.v8_Object_Set(global, context_once.?, @ptrCast(key), @ptrCast(@alignCast(handle)));
}

fn asValue(value: *ffi.Value) runtime.JSValue {
    return .{ .handle = .{ .ptr = @ptrCast(value) } };
}

/// promiseResolve of `value`, its normal result published as globalThis.r.
fn resolveToGlobal(ctx: runtime.Context, value: runtime.JSValue) !void {
    const completion = try protocol.promiseResolve(ctx, value);
    switch (completion) {
        .normal => |result| {
            defer result.release();
            try setGlobal("r", result.value.handle.ptr);
        },
        .throw => |thrown| {
            thrown.release();
            return error.UnexpectedThrow;
        },
    }
}

test "a promise of the realm's %Promise% is returned as it is" {
    const ctx = try realm();
    const p = try eval("globalThis.p = Promise.resolve(1); p");
    defer ffi.v8_Value_Dispose(p);
    try resolveToGlobal(ctx, asValue(p));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("r === p ? 1 : 0"));
}

test "x.constructor is read once, and a promise whose constructor is another is wrapped" {
    const ctx = try realm();
    const p = try eval(
        \\globalThis.reads = 0;
        \\globalThis.q = Promise.resolve(2);
        \\Object.defineProperty(q, "constructor", { get() { reads++; return Object; } });
        \\q
    );
    defer ffi.v8_Value_Dispose(p);
    try resolveToGlobal(ctx, asValue(p));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("reads"));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("r !== q && r instanceof Promise ? 1 : 0"));
}

test "a subclass's promise is wrapped in a new promise of %Promise%" {
    const ctx = try realm();
    const p = try eval("class Sub extends Promise {}; globalThis.s = Sub.resolve(3); s");
    defer ffi.v8_Value_Dispose(p);
    try resolveToGlobal(ctx, asValue(p));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("r !== s && Object.getPrototypeOf(r) === Promise.prototype ? 1 : 0"));
}

test "a promise of another realm is wrapped" {
    const ctx = try realm();
    const other = ffi.v8_Context_New(isolate_once.?) orelse return error.ContextCreationFailed;
    defer ffi.v8_Context_Dispose(other);
    const foreign = try evalIn(other, "Promise.resolve(4)");
    defer ffi.v8_Value_Dispose(foreign);
    try setGlobal("f", @ptrCast(foreign));
    try resolveToGlobal(ctx, asValue(foreign));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("r !== f && r instanceof Promise ? 1 : 0"));
}

test "an inline primitive becomes a new promise fulfilled with it" {
    const ctx = try realm();
    try resolveToGlobal(ctx, .{ .number = 5 });
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.seen = 0; r.then(v => { seen = v; }); r instanceof Promise ? 1 : 0"));
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);
    try std.testing.expectEqual(@as(i32, 5), try evalInt("seen"));
    try resolveToGlobal(ctx, .undefined);
    try std.testing.expectEqual(@as(i32, 1), try evalInt("r instanceof Promise ? 1 : 0"));
}

test "a thenable that is not a promise is adopted by a new promise" {
    const ctx = try realm();
    const t = try eval("globalThis.thenReads = 0; globalThis.t = { get then() { thenReads++; return (ok) => ok(6); } }; t");
    defer ffi.v8_Value_Dispose(t);
    try resolveToGlobal(ctx, asValue(t));
    // Resolving reads `then` once, as the promise resolve function does.
    try std.testing.expectEqual(@as(i32, 1), try evalInt("globalThis.seen = 0; r.then(v => { seen = v; }); r !== t && r instanceof Promise ? thenReads : -1"));
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate_once.?);
    try std.testing.expectEqual(@as(i32, 6), try evalInt("seen"));
}

test "a throwing constructor getter is a throw completion with the thrown value" {
    const ctx = try realm();
    const p = try eval(
        \\globalThis.boom = new Error("constructor");
        \\globalThis.b = Promise.resolve(7);
        \\Object.defineProperty(b, "constructor", { get() { throw boom; } });
        \\b
    );
    defer ffi.v8_Value_Dispose(p);
    const completion = try protocol.promiseResolve(ctx, asValue(p));
    switch (completion) {
        .normal => |result| {
            result.release();
            return error.ExpectedThrow;
        },
        .throw => |thrown| {
            defer thrown.release();
            try setGlobal("caught", thrown.value.handle.ptr);
            try std.testing.expectEqual(@as(i32, 1), try evalInt("caught === boom ? 1 : 0"));
        },
    }
}

test "the realm's %Promise% is found even when PromiseResolve resolves nothing with it" {
    // isPromiseConstructor reads %Promise.prototype% from a pending promise:
    // a constructor with a `then` getter is not touched by the comparison.
    const ctx = try realm();
    const p = try eval(
        \\globalThis.ctorThenReads = 0;
        \\function Fake() {}
        \\Object.defineProperty(Fake, "then", { get() { ctorThenReads++; return undefined; } });
        \\globalThis.c = Promise.resolve(8);
        \\Object.defineProperty(c, "constructor", { value: Fake });
        \\c
    );
    defer ffi.v8_Value_Dispose(p);
    try resolveToGlobal(ctx, asValue(p));
    try std.testing.expectEqual(@as(i32, 0), try evalInt("ctorThenReads"));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("r !== c ? 1 : 0"));
}
