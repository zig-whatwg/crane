//! WebIDL §3.2.24 "converting to a union", step 15, for a union with an
//! interface arm: an object that no interface arm takes is converted to the
//! string type - ToString, so its toString() runs and what it THROWS
//! propagates.
//!
//! The Trusted Types sinks take unions like (TrustedScriptURL or USVString).
//! The conversion's interface-arm path called ToString itself and, when that
//! threw, fell through to its final TypeError: `new SharedWorker({toString()
//! { throw new Error() }})` threw a TypeError instead of the Error
//! (workers/SharedWorker-constructor.html), and so did `el.innerHTML =` such
//! an object. The same path serves every union with an interface arm and a
//! string arm - (Node or DOMString), append()'s argument, among them.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const conv = v8.conversions;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;

/// A live isolate with an entered context, one for the whole file - V8 is
/// never torn down here.
fn isolate() !*ffi.Isolate {
    if (isolate_once) |i| return i;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    isolate_once = i;
    context_once = context;
    return i;
}

fn eval(code: []const u8) !*ffi.Value {
    const i = try isolate();
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(i, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

const ScriptUrlOrString = conv.generated_typedefs.TrustedScriptURLOrUSVString;
const HtmlOrString = conv.generated_typedefs.TrustedHTMLOrDOMString;

/// Convert `value` to `T` under a TryCatch: the conversion's error, if any,
/// and what script saw thrown (OWNED), if anything.
fn convertCatching(comptime T: type, value: *ffi.Value) struct { result: anyerror!T, thrown: ?*ffi.Value } {
    const Body = struct {
        value: *ffi.Value,
        result: anyerror!T = error.NotRun,
        fn call(data: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.result = conv.fromV8Value(T, std.testing.allocator, isolate_once.?, context_once.?, self.value);
        }
    };
    var body = Body{ .value = value };
    var thrown: ?*ffi.Value = null;
    _ = ffi.v8_RunCatching(isolate_once.?, Body.call, &body, &thrown);
    return .{ .result = body.result, .thrown = thrown };
}

/// Whether `thrown` is an instance of the global constructor `name`.
fn isInstanceOf(thrown: *ffi.Value, comptime name: []const u8) !bool {
    const check = try eval("(e) => e instanceof " ++ name ++ " && e.message === 'boom'");
    defer ffi.v8_Value_Dispose(check);
    var threw = false;
    const argv = [_]*ffi.Value{thrown};
    const answer = ffi.v8_Function_CallCatching(context_once.?, check, null, 1, &argv, &threw) orelse return error.CallFailed;
    defer ffi.v8_Value_Dispose(answer);
    return !threw and ffi.v8_Value_BooleanValue(answer, isolate_once.?);
}

test "an object whose toString throws: the exception propagates, not a TypeError" {
    const value = try eval("({ toString() { throw new RangeError('boom') } })");
    defer ffi.v8_Value_Dispose(value);
    const outcome = convertCatching(ScriptUrlOrString, value);
    try std.testing.expectError(error.ExceptionPending, outcome.result);
    const thrown = outcome.thrown orelse return error.NothingThrown;
    defer ffi.v8_Value_Dispose(thrown);
    try std.testing.expect(try isInstanceOf(thrown, "RangeError"));
}

test "an object with a toString takes the string arm" {
    const value = try eval("({ toString() { return 'https://example.test/w.js' } })");
    defer ffi.v8_Value_Dispose(value);
    const outcome = convertCatching(ScriptUrlOrString, value);
    try std.testing.expect(outcome.thrown == null);
    const result = try outcome.result;
    try std.testing.expect(result == .usvstring);
    defer if (result.usvstring.len > 0) std.testing.allocator.free(result.usvstring);
    try std.testing.expectEqualStrings("https://example.test/w.js", result.usvstring);
}

test "(TrustedHTML or DOMString): a throwing toString propagates too" {
    const value = try eval("({ toString() { throw new TypeError('boom') } })");
    defer ffi.v8_Value_Dispose(value);
    const outcome = convertCatching(HtmlOrString, value);
    try std.testing.expectError(error.ExceptionPending, outcome.result);
    const thrown = outcome.thrown orelse return error.NothingThrown;
    defer ffi.v8_Value_Dispose(thrown);
    try std.testing.expect(try isInstanceOf(thrown, "TypeError"));
}

test "a plain string still takes the string arm" {
    const value = try eval("'plain'");
    defer ffi.v8_Value_Dispose(value);
    const outcome = convertCatching(HtmlOrString, value);
    try std.testing.expect(outcome.thrown == null);
    var result = try outcome.result;
    try std.testing.expect(result == .domstring);
    defer result.domstring.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("plain", result.domstring.asSlice());
}
