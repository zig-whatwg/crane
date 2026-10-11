//! A ByteString argument, attribute value or dictionary member: a code unit
//! above 0xFF is a TypeError (WebIDL 3.2.11 step 2).
//!
//! ByteString and USVString are both `[]const u8` in the binding, converted
//! alike (ToString, written as WTF-8, a lone surrogate made U+FFFD). Codegen
//! marks which values are ByteStrings (`byte_string_arguments`,
//! `byte_string_members`) and the binding checks each converted one
//! (`conversions.requireByteString`). Without it `headers.append("a",
//! "Ā")` and `xhr.setRequestHeader("a", "ﾃｽﾄ")` stored the UTF-8 of
//! code units no byte can hold.
//!
//! Values are converted from script values the way the binding converts an
//! argument, with std.testing.allocator, so what a failed conversion leaves
//! behind fails the test.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const webidl = @import("webidl");
const ffi = v8.ffi;
const conv = v8.conversions;

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var env_once: ?Env = null;

/// One isolate and context for the file; V8 is never torn down here.
fn env() !Env {
    if (env_once) |e| return e;
    try engine.initializeEngine(.{});
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    env_once = .{ .isolate = isolate, .context = context };
    return env_once.?;
}

/// The value `code` evaluates to: a Global the caller disposes, made the way
/// the binding's `info.get(i)` makes an argument's.
fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

/// `code` converted as a `T` and checked as a ByteString, then freed.
fn check(comptime T: type, code: []const u8) !void {
    const e = try env();
    const handle = try eval(code);
    defer ffi.v8_Value_Dispose(handle);
    const value = try conv.fromV8Value(T, testing.allocator, e.isolate, e.context, handle);
    defer v8.interface_mod.freeConvertedArg(T, testing.allocator, value);
    try conv.requireByteString(T, value);
}

test "code units up to 0xFF are a ByteString" {
    try check([]const u8, "'GET'");
    try check([]const u8, "'\\u00e9\\u00ff\\u0080'");
    try check([]const u8, "''");
    // ToString: a number is its digits.
    try check([]const u8, "200");
}

test "a code unit above 0xFF is a TypeError" {
    try testing.expectError(error.TypeError, check([]const u8, "'\\u0100'"));
    // xhr/setrequestheader-bogus-value.htm's value.
    try testing.expectError(error.TypeError, check([]const u8, "'\\uFF83\\uFF7D\\uFF84'"));
    try testing.expectError(error.TypeError, check([]const u8, "'ok\\u{1F600}'"));
    // A lone surrogate is a code unit above 0xFF, whatever the string
    // conversion writes for it.
    try testing.expectError(error.TypeError, check([]const u8, "'\\uD800'"));
}

test "a nullable, optional or sequence ByteString is checked through" {
    try check(?[]const u8, "null");
    try testing.expectError(error.TypeError, check(?[]const u8, "'\\u0100'"));
    // An optional argument: checked only when it was passed.
    try conv.requireByteString(webidl.Opt([]const u8), webidl.Opt([]const u8).notPassed());
    try conv.requireByteString(webidl.Opt([]const u8), webidl.Opt([]const u8).passed("a"));
    try testing.expectError(error.TypeError, conv.requireByteString(webidl.Opt([]const u8), webidl.Opt([]const u8).passed("\u{100}")));
    try testing.expectError(error.TypeError, check([]const []const u8, "['a', '\\u0100']"));
    try check([]const []const u8, "['a', '\\u00ff']");
}

/// A dictionary as codegen emits one with a ByteString member (RequestInit's
/// `method`): listed in `byte_string_members`.
const Init = struct {
    body: ?runtime.DOMString = null,
    method: ?[]const u8 = null,
    referrer: ?[]const u8 = null,
    pub const byte_string_members = .{"method"};
};

test "a dictionary's ByteString member is checked as it is converted" {
    const e = try env();
    {
        const object = try eval("({ body: 'x'.repeat(64), method: '\\u0100', referrer: 'r'.repeat(64) })");
        defer ffi.v8_Value_Dispose(object);
        // The members converted before it - body - are freed with it: the
        // testing allocator sees a leak otherwise.
        try testing.expectError(error.TypeError, conv.fromV8Value(Init, testing.allocator, e.isolate, e.context, object));
    }
    {
        // Not a ByteString member: USVString keeps its code units.
        const object = try eval("({ method: 'POST', referrer: '\\u0100' })");
        defer ffi.v8_Value_Dispose(object);
        const init = try conv.fromV8Value(Init, testing.allocator, e.isolate, e.context, object);
        defer v8.interface_mod.freeConvertedArg(Init, testing.allocator, init);
        try testing.expectEqualStrings("POST", init.method.?);
        try testing.expectEqualStrings("\u{100}", init.referrer.?);
    }
}

test "byteStringMask reads codegen's table, and an interface without one has none" {
    const Marked = struct {
        pub const byte_string_arguments = .{ .{ "call_append", 0b11 }, .{ "set_token", 0b1 } };
    };
    const Plain = struct {};
    try testing.expectEqual(@as(u32, 0b11), v8.interface_mod.byteStringMask(Marked, "call_append"));
    try testing.expectEqual(@as(u32, 0b1), v8.interface_mod.byteStringMask(Marked, "set_token"));
    try testing.expectEqual(@as(u32, 0), v8.interface_mod.byteStringMask(Marked, "call_get"));
    try testing.expectEqual(@as(u32, 0), v8.interface_mod.byteStringMask(Plain, "call_append"));
}
