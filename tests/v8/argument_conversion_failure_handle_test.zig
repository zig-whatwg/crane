//! An argument whose conversion fails leaves no handle behind.
//!
//! The binding's argument handles (`info.get(i)`, a Global made for the
//! call) were released on a failed conversion only for the types whose value
//! can keep the handle (`argumentHandleIsKeptInValue`: `any`, an `object`
//! arm, a buffer source). Every other type's converter refuses before it
//! adopts the handle - a callback function's is checked IsCallable first, a
//! callback interface's wrapper is made only from an object, an interface is
//! checked implements, a dictionary reads its members through Gets of its own
//! - so a TypeError left the argument's Global referred to by nothing, for the
//! agent's life. leaks --atExit over main's web-locks/ named 21 of them, all
//! `v8_FunctionCallbackInfo_GetArgument` under LockManager.request's
//! rejectOnThrow path: `navigator.locks.request(name, null)`, `(name, 123)`,
//! `(name, {})` ... (web-locks/acquire.https.any.js; binding3's follow-up 4).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const iface = v8.interface_mod;

/// LockManager.request(name, callback)'s `callback`: LockGrantedCallback.
const LockGrantedCallback = @typeInfo(@TypeOf(interfaces.LockManager.call_request)).@"fn".param_types[2].?;
/// LockManager.request(name, options, callback)'s `options`: LockOptions.
const LockOptions = @typeInfo(@TypeOf(interfaces.LockManager.call_request__1)).@"fn".param_types[2].?;

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

/// Script's value of `code`, OWNED - a Global, as `info.get(i)` makes one.
fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

/// The global handle bytes `rounds` failed conversions of `code` as a `T`
/// leave, after a warm-up.
fn bytesLeftByFailures(comptime T: type, code: []const u8, rounds: usize) !i64 {
    const e = try env();
    for (0..32) |_| {
        const arg = try eval(code);
        _ = iface.convertArgReleasingWith(T, .{}, testing.allocator, e.isolate, e.context, arg) catch {};
    }
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate));
    for (0..rounds) |_| {
        const arg = try eval(code);
        if (iface.convertArgReleasingWith(T, .{}, testing.allocator, e.isolate, e.context, arg)) |_| {
            return error.ConversionSucceeded;
        } else |_| {}
    }
    const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate));
    return after - before;
}

test "a callback function argument that is not callable leaves no handle" {
    // 512 failures keeping their argument would be 8,192 bytes.
    try testing.expect(try bytesLeftByFailures(LockGrantedCallback, "123", 512) < 2048);
    try testing.expect(try bytesLeftByFailures(LockGrantedCallback, "({})", 512) < 2048);
}

test "a dictionary argument whose member fails to convert leaves no handle" {
    // `{mode: 'foo'}`: not a LockMode, a TypeError in the member's conversion.
    try testing.expect(try bytesLeftByFailures(LockOptions, "({ mode: 'foo' })", 512) < 2048);
}
