//! WebIDL 3.2.14, converting to `object`: "If V is not an Object, throw a
//! TypeError." Codegen types `object` as runtime.JSValue, as it types `any`,
//! so a `sequence<object>` converted any value: `structuredClone(0,
//! {transfer: [1]})` reached the serializer, whose DataCloneError is not the
//! TypeError WebIDL (and Chrome) throw in conversion (binding3's follow-up 1).
//! Codegen now marks the `object` positions - `object_members` for a
//! dictionary, `object_arguments` for an operation - and the converter checks
//! each value as part of its conversion.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const conversions = v8.conversions;

/// structuredClone(value, options)'s `options`: `sequence<object> transfer = []`.
const StructuredSerializeOptions = @FieldType(@typeInfo(@TypeOf(interfaces.Window.call_structuredClone)).@"fn".param_types[2].?, "value");

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var test_env: ?Env = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_env = null;
}

fn env() !Env {
    const isolate = try test_agent.open(.{});
    if (test_env == null) test_env = .{ .isolate = isolate, .context = test_agent.context.? };
    return test_env.?;
}

fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

fn convert(code: []const u8) !StructuredSerializeOptions {
    const e = try env();
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return conversions.fromV8Value(StructuredSerializeOptions, testing.allocator, e.isolate, e.context, value);
}

fn release(options: StructuredSerializeOptions) void {
    v8.interface_mod.freeConvertedArg(StructuredSerializeOptions, testing.allocator, options);
}

test "codegen marks StructuredSerializeOptions.transfer an object member" {
    defer test_agent.close();
    try testing.expect(@hasDecl(StructuredSerializeOptions, "object_members"));
}

test "a sequence<object> element that is not an Object is a TypeError" {
    defer test_agent.close();
    try testing.expectError(error.TypeError, convert("({ transfer: [1] })"));
    try testing.expectError(error.TypeError, convert("({ transfer: ['buffer'] })"));
    try testing.expectError(error.TypeError, convert("({ transfer: [null] })"));
    try testing.expectError(error.TypeError, convert("({ transfer: [Symbol()] })"));
    // After an Object: the elements converted before it are released.
    try testing.expectError(error.TypeError, convert("({ transfer: [new ArrayBuffer(1), 2] })"));
}

test "Objects - a function and an array included - convert" {
    defer test_agent.close();
    const options = try convert("({ transfer: [new ArrayBuffer(1), function () {}, []] })");
    defer release(options);
    try testing.expectEqual(@as(usize, 3), options.transfer.?.len);
    const empty = try convert("({})");
    defer release(empty);
    try testing.expect(empty.transfer == null);
}

test "a failed element check leaves no handle behind" {
    defer test_agent.close();
    const e = try env();
    for (0..64) |_| _ = convert("({ transfer: [new ArrayBuffer(1), 2] })") catch {};
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate);
    for (0..512) |_| _ = convert("({ transfer: [new ArrayBuffer(1), 2] })") catch {};
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate);
    // 512 conversions keeping one handle each would be 8,192 bytes.
    try testing.expect(after -| before < 4 * 1024);
}

test "requireObject: a primitive is not an Object; a nullable or absent value passes" {
    defer test_agent.close();
    try testing.expectError(error.TypeError, conversions.requireObject(runtime.JSValue, .{ .number = 1 }));
    try testing.expectError(error.TypeError, conversions.requireObject(runtime.JSValue, .null));
    try conversions.requireObject(?runtime.JSValue, null);
    try conversions.requireObject([]const runtime.JSValue, &.{});
}
