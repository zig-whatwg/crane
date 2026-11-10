//! A binding callback reads its target - and from it the function's realm -
//! from the target's own slot.
//!
//! v8_FunctionCallbackInfo_GetFunctionCreationContext answers "the function's
//! realm" for every binding path that throws or makes an object in it (the
//! operations, the setters, the getters' ErrorRealm, the constructors). It
//! reads the callback's target at implicit_args[kTargetIndex], the slot V8's
//! own FunctionCallbackInfo::Data() reads with
//! `Local<Data>::FromSlot(&implicit_args_[kTargetIndex])`. It made its Local
//! from the slot's VALUE instead: the tagged pointer itself, reinterpreted as
//! a slot address. Every question asked of that "target" read the object's
//! first word as if it were the object, so the answer was garbage - nearly
//! always "not a function", whose fallback, the current context, happens to
//! be the called function's own (calling a function enters its realm). Asked
//! later in a call, after the impl had run script, it was a bus error
//! (perf3 phase 1b; tests/v8/context_counter_test.zig).
//!
//! V8 >= 14 keeps the target slot private (FunctionCallbackInfo is a view of
//! the API exit frame, b9c4e374820): the realm is now the current context,
//! which V8 enters for the call. The probe below is called from script in
//! another realm and asks for its function realm: the realm it was made in.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const v8 = @import("v8");
const ffi = v8.ffi;

var test_agent: test_process.TestAgent = .{};

/// What the probe saw, the last time script called it.
const Seen = struct {
    realm_key: ?*anyopaque = null,
    calls: u32 = 0,
};
var seen: Seen = .{};

fn probe(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    seen.calls += 1;
    const realm = info.getFunctionCreationContext() orelse return;
    defer ffi.v8_Context_Dispose(realm);
    seen.realm_key = ffi.v8_Context_GetRawAddress(realm);
}

fn run(context: *ffi.Context, isolate: *ffi.Isolate, source: []const u8) !void {
    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.NoString;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.NoScript;
    defer ffi.v8_Script_Dispose(script);
    const result = ffi.v8_Script_Run(context, script) orelse return error.ScriptThrew;
    ffi.v8_Value_Dispose(result);
}

test "a callback's function realm is the one it was made in, called from another realm, interpreted and optimized" {
    const isolate = try test_agent.open(.{});
    defer test_agent.close();
    const home = test_agent.context.?;
    const other = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(other);

    // The probe is made in `home` and called from script in `other`.
    const template = ffi.v8_FunctionTemplate_New(isolate, probe, null) orelse return error.NoTemplate;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    const function = ffi.v8_FunctionTemplate_GetFunction(template, home) orelse return error.NoFunction;
    defer ffi.v8_Function_Dispose(function);
    const global = ffi.v8_Context_Global(other) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate, "probe", 5) orelse return error.NoString;
    defer ffi.v8_String_Dispose(key);
    try testing.expect(ffi.v8_Object_Set(global, other, @ptrCast(key), @ptrCast(function)));

    ffi.v8_Context_Enter(other);
    defer ffi.v8_Context_Exit(other);
    // Interpreted, then hot enough for the optimizing tiers' call path.
    try run(other, isolate, "probe(); for (let i = 0; i < 20000; i++) probe();");

    try testing.expect(seen.calls > 1);
    try testing.expectEqual(ffi.v8_Context_GetRawAddress(home), seen.realm_key);
}
