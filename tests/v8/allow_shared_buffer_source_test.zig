//! Converting to AllowSharedBufferSource - (ArrayBuffer or SharedArrayBuffer or
//! [AllowShared] ArrayBufferView), TextDecoder.decode's input among others -
//! through the V8 adapter's conversion.
//!
//! WebIDL 3.2.25: an ArrayBuffer (step 6) and a SharedArrayBuffer (step 7) are
//! members of the union as much as a typed array or a DataView (steps 8-9), and
//! a view's bytes are its own window of its buffer, [[ByteOffset]] for
//! [[ByteLength]]. A detached buffer holds no bytes. The conversion yields a
//! byte slice over the backing store, valid for the synchronous call.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const ffi = v8.ffi;
const conv = v8.conversions;
const AllowSharedBufferSource = conv.generated_typedefs.AllowSharedBufferSource;
const testing_allocator = std.testing.allocator;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;

/// One isolate and context for the file; V8 is never torn down here.
fn setUp() !void {
    if (context_once != null) return;
    try engine.initializeEngine(.{});
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    isolate_once = i;
    context_once = context;
}

/// The value `code` evaluates to: a Global the caller disposes, made the way
/// the binding's `info.get(i)` makes an argument's.
fn eval(code: []const u8) !*ffi.Value {
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

/// The bytes `code`'s value converts to, compared with `expected`.
fn expectBytes(code: []const u8, expected: []const u8) !void {
    try setUp();
    const handle = try eval(code);
    defer ffi.v8_Value_Dispose(handle);
    const source = conv.fromV8Value(AllowSharedBufferSource, testing_allocator, isolate_once.?, context_once.?, handle) catch |err| {
        std.debug.print("{s} did not convert: {s}\n", .{ code, @errorName(err) });
        return err;
    };
    const bytes = try source.asBytes();
    std.testing.expectEqualSlices(u8, expected, bytes) catch |err| {
        std.debug.print("{s} converted to the wrong bytes\n", .{code});
        return err;
    };
}

test "an ArrayBuffer is its bytes" {
    try expectBytes("new Uint8Array([104, 105]).buffer", "hi");
}

test "a SharedArrayBuffer is its bytes" {
    try expectBytes("(() => { const s = new SharedArrayBuffer(3); new Uint8Array(s).set([1, 2, 3]); return s; })()", &.{ 1, 2, 3 });
}

test "a typed array is its own window of its buffer" {
    try expectBytes("new Uint8Array([1, 2, 3, 4, 5]).subarray(1, 4)", &.{ 2, 3, 4 });
    try expectBytes("new Uint16Array([0x0201, 0x0403, 0x0605]).subarray(1)", &.{ 3, 4, 5, 6 });
}

test "a DataView is its own window of its buffer, not its whole buffer" {
    try expectBytes("new DataView(new Uint8Array([1, 2, 3, 4, 5]).buffer, 1, 3)", &.{ 2, 3, 4 });
    try expectBytes("new DataView(new Uint8Array([7, 8]).buffer)", &.{ 7, 8 });
}

test "a view over a SharedArrayBuffer is allowed ([AllowShared])" {
    try expectBytes("(() => { const s = new SharedArrayBuffer(4); new Uint8Array(s).set([9, 8, 7, 6]); return new Uint8Array(s, 1, 2); })()", &.{ 8, 7 });
    try expectBytes("(() => { const s = new SharedArrayBuffer(4); new Uint8Array(s).set([9, 8, 7, 6]); return new DataView(s, 2); })()", &.{ 7, 6 });
}

test "a detached ArrayBuffer, and a view over one, hold no bytes" {
    try expectBytes("(() => { const b = new Uint8Array([1, 2]).buffer; b.transfer(); return b; })()", &.{});
    try expectBytes("(() => { const v = new Uint8Array([1, 2]); v.buffer.transfer(); return v; })()", &.{});
    try expectBytes("(() => { const v = new DataView(new Uint8Array([1, 2]).buffer); v.buffer.transfer(); return v; })()", &.{});
}

test "anything else is a TypeError" {
    try setUp();
    const cases = [_][]const u8{ "({ byteLength: 2 })", "'hi'", "4", "[1, 2]", "Symbol()" };
    for (cases) |code| {
        const handle = try eval(code);
        defer ffi.v8_Value_Dispose(handle);
        if (conv.fromV8Value(AllowSharedBufferSource, testing_allocator, isolate_once.?, context_once.?, handle)) |_| {
            std.debug.print("{s} converted to an AllowSharedBufferSource\n", .{code});
            return error.TestUnexpectedResult;
        } else |err| try std.testing.expectEqual(error.TypeError, err);
    }
}
