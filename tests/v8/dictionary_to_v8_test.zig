//! A dictionary converted to an ECMAScript object (WebIDL 3.2.18, "converting
//! an IDL dictionary value to an ECMAScript value") leaves no handle behind
//! and defines its members.
//!
//! conversions.toV8Value made each member's key string and value as Globals
//! and released neither, and the binding's operation result path never
//! released the object itself: a dictionary an operation returned
//! (Navigation.navigate's NavigationResult, URLPattern.exec's result) leaked
//! a Global per member and one for the object - `leaks --atExit` named them
//! under crane/lk2-navigation-wait-never-settles.html. And it assigned each
//! member with [[Set]], so a setter on Object.prototype ran; step 4.2.3 is
//! "Perform ! CreateDataPropertyOrThrow(O, key, jsValue)".

const std = @import("std");
const testing = std.testing;
const v8 = @import("v8");
const ffi = v8.ffi;

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var env_once: ?Env = null;

fn env() !Env {
    if (env_once) |e| return e;
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    env_once = .{ .isolate = isolate, .context = context };
    return env_once.?;
}

fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, env_once.?.context);
}

/// A dictionary as codegen emits one: optional members, null when absent.
const Result = struct {
    committed: ?f64 = null,
    finished: ?f64 = null,
    absent: ?f64 = null,
    nested: ?Inner = null,
};
const Inner = struct {
    flag: ?bool = null,
};

test "a dictionary's conversion leaves only the object it returns" {
    const e = try env();
    const value: Result = .{ .committed = 1, .finished = 2, .nested = .{ .flag = true } };
    // Warm up, so the handle table's blocks exist before the measurement.
    for (0..64) |_| {
        const object = try v8.conversions.toV8Value(Result, e.isolate, e.context, value);
        ffi.v8_Value_Dispose(object);
    }
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate);
    for (0..2000) |_| {
        const object = try v8.conversions.toV8Value(Result, e.isolate, e.context, value);
        ffi.v8_Value_Dispose(object);
    }
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate);
    // 2,000 conversions of five handles each kept would be ~10,000 handles.
    try testing.expect(after -| before < 16 * 1024);
}

test "a dictionary's members are defined, not assigned" {
    const e = try env();
    const poison = try eval("globalThis.calls = 0; Object.defineProperty(Object.prototype, 'committed', { set(v) { calls++; }, configurable: true }); 0");
    ffi.v8_Value_Dispose(poison);
    defer {
        const undo = eval("delete Object.prototype.committed; 0") catch null;
        if (undo) |u| ffi.v8_Value_Dispose(u);
    }
    const object = try v8.conversions.toV8Value(Result, e.isolate, e.context, .{ .committed = 5 });
    defer ffi.v8_Value_Dispose(object);
    const global = ffi.v8_Context_Global(e.context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(e.isolate, "result", 6) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, e.context, @ptrCast(key), object)) return error.SetFailed;

    try testing.expectEqual(@as(i32, 0), try evalInt("calls"));
    try testing.expectEqual(@as(i32, 1), try evalInt("Object.prototype.hasOwnProperty.call(result, 'committed') && result.committed === 5 ? 1 : 0"));
    // An absent (null) member is not a property at all.
    try testing.expectEqual(@as(i32, 0), try evalInt("'absent' in result ? 1 : 0"));
}
