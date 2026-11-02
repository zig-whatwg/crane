//! A Zig string an impl hands back to script is WTF-8: conversions.fromV8Value
//! writes a JavaScript string with WriteUtf8 and no REPLACE_INVALID_UTF8, so
//! an unpaired surrogate arrives as its three-byte form, ED A0..BF xx, and a
//! DOMString keeps it. On the way back, V8's UTF-8 decoder
//! (String::NewFromUtf8) makes each of those bytes a U+FFFD, so
//! `document.createTextNode("\uDEAD").data` read as three replacement
//! characters. Every conversion of a Zig string to a V8 string keeps the code
//! units instead - the same decode value_operations.ownHandle does for the
//! protocol's own copies (e0204d2ff).

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const conv = v8.conversions;

/// The test's isolate and context: its own agent's (test_agent), ended with
/// the test.
var test_isolate: ?*ffi.Isolate = null;
var test_context: ?*ffi.Context = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
    test_context = null;
}

fn setUp() !struct { isolate: *ffi.Isolate, context: *ffi.Context } {
    const i = try test_agent.open(.{});
    if (test_isolate == null) {
        const context = test_agent.context.?;
        test_isolate = i;
        test_context = context;
    }
    return .{ .isolate = test_isolate.?, .context = test_context.? };
}

/// Whether `value` is the string script writes as `literal`.
fn isScriptString(value: *ffi.Value, literal: []const u8) !bool {
    const i = test_isolate.?;
    const context = test_context.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(i, "converted", 9) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), value)) return error.SetFailed;

    const code = try std.fmt.allocPrint(std.testing.allocator, "converted === {s} ? 1 : 0", .{literal});
    defer std.testing.allocator.free(code);
    const text = ffi.v8_String_NewFromUtf8(i, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const result = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(result);
    return ffi.v8_Value_Int32Value(result, context) == 1;
}

const cases = [_]struct { wtf8: []const u8, script: []const u8 }{
    .{ .wtf8 = "\xED\xBA\xAD", .script = "'\\uDEAD'" },
    .{ .wtf8 = "\xED\xBC\x86\xED\xA0\xB4", .script = "'\\uDF06\\uD834'" },
    .{ .wtf8 = "a\xED\xBA\xAD\xF0\x9D\x8C\x86b", .script = "'a\\uDEAD\\uD834\\uDF06b'" },
    .{ .wtf8 = "\xF0\x9D\x8C\x86", .script = "'\\uD834\\uDF06'" },
    .{ .wtf8 = "plain", .script = "'plain'" },
    .{ .wtf8 = "", .script = "''" },
};

fn expectArrives(value: *ffi.Value, case: @TypeOf(cases[0]), path: []const u8) !void {
    if (!try isScriptString(value, case.script)) {
        std.debug.print("{s}: {any} did not arrive as {s}\n", .{ path, case.wtf8, case.script });
        return error.CodeUnitsChanged;
    }
}

test "an `any` string an impl returns keeps its lone surrogates" {
    defer test_agent.close();
    const env = try setUp();
    for (cases) |case| {
        const value = try conv.toV8Value(runtime.JSValue, env.isolate, env.context, runtime.JSValue.fromStringRef(case.wtf8));
        defer ffi.v8_Global_Dispose(value);
        try expectArrives(value, case, "runtime.JSValue");
    }
}

test "a DOMString an impl returns keeps its lone surrogates" {
    defer test_agent.close();
    const env = try setUp();
    for (cases) |case| {
        const string = conv.toV8String(env.isolate, runtime.DOMString.initInterned(case.wtf8));
        defer ffi.v8_Global_Dispose(@ptrCast(string));
        try expectArrives(@ptrCast(string), case, "DOMString");
    }
}

test "a string slice an impl returns keeps its lone surrogates" {
    defer test_agent.close();
    const env = try setUp();
    for (cases) |case| {
        const value = try conv.toV8Value([]const u8, env.isolate, env.context, case.wtf8);
        defer ffi.v8_Global_Dispose(value);
        try expectArrives(value, case, "[]const u8");
    }
}

test "the V8 adapter's own JSValue string keeps its lone surrogates" {
    defer test_agent.close();
    const env = try setUp();
    for (cases) |case| {
        const value = conv.JSValue.fromStringRef(case.wtf8).toV8(env.isolate);
        defer ffi.v8_Global_Dispose(value);
        try expectArrives(value, case, "v8 JSValue");
    }
}

test "creating a string value keeps its lone surrogates" {
    defer test_agent.close();
    const env = try setUp();
    for (cases) |case| {
        const value = try conv.createV8String(env.isolate, case.wtf8);
        defer ffi.v8_Global_Dispose(value);
        try expectArrives(value, case, "createV8String");
    }
}
