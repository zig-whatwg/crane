//! An AllowSharedBufferSource argument whose buffer a LATER argument's
//! conversion detaches, through the real binding.
//!
//! WebIDL 3.2.25/3.2.26: an AllowSharedBufferSource IDL value is a reference
//! to the JavaScript object, and the operation copies the bytes at its own
//! step ("get a copy of the bytes held by the buffer source"). Arguments
//! convert in order, so the options dictionary of
//! `TextDecoder.decode(input, options)` converts AFTER the input - and a
//! getter on it can transfer the input's buffer, which frees its backing
//! store. Encoding's decode() then "push[es] a copy of input" at step 3: a
//! detached buffer's copy is empty, so the result is "".
//!
//! The conversion used to be a non-owning slice over the backing store,
//! taken when the input converted: the impl then read the freed store.
//! encoding/textdecoder-arguments.any.js "decode() with array buffer
//! detached during arg conversion" read as FAIL, not CRASH, because nothing
//! unmapped the store - the stale bytes were still there, or another
//! allocation's. The first test fills the freed block's likely successor
//! with 'Z' so that a stale read shows itself in the result.

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
/// as a page's is, every interface installed; V8 is never torn down here.
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
    runtime.initializeRuntime(std.heap.page_allocator);
    v8.interface_bindings.registerAllInterfaces(i, context);
    isolate_once = i;
    context_once = context;
    realm_once = r;
    return r;
}

/// The string `code` evaluates to, OWNED by the testing allocator; a
/// thrown exception is error.Threw.
fn evalString(code: []const u8) ![]u8 {
    _ = try realm();
    const isolate = isolate_once.?;
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.Threw;
    defer ffi.v8_Value_Dispose(value);
    const string = ffi.v8_Value_ToString(value, context) orelse return error.Threw;
    defer ffi.v8_String_Dispose(string);
    const length = ffi.v8_String_Utf8Length(string);
    if (length < 0) return error.StringFailed;
    const out = try std.testing.allocator.alloc(u8, @intCast(length));
    errdefer std.testing.allocator.free(out);
    if (ffi.v8_String_WriteUtf8(string, out.ptr, @intCast(length)) != length) return error.StringFailed;
    return out;
}

/// `code`'s string result is `expected`; a mismatch prints its length and
/// first bytes (a stale read shows as the freed store's bytes, or another
/// allocation's).
fn expectResult(what: []const u8, code: []const u8, expected: []const u8) !void {
    const result = try evalString(code);
    defer std.testing.allocator.free(result);
    if (!std.mem.eql(u8, result, expected)) {
        std.debug.print("{s}: expected \"{s}\", got {d} bytes: \"{s}\"...\n", .{ what, expected, result.len, result[0..@min(result.len, 24)] });
        return error.TestExpectedEqual;
    }
}

// Encoding decode() step 3 runs after the options converted: the input's
// buffer, transferred by the options' getter, holds no bytes - "", as
// encoding/textdecoder-arguments.any.js expects. The getter then makes a
// buffer the same size and fills it with 'Z': a read of the freed store
// tends to find that, rather than the input's '*'.
test "decode() of a typed array its options getter detaches reads no bytes" {
    try expectResult("typed array detached by the options getter",
        \\(() => {
        \\  const decoder = new TextDecoder();
        \\  const arr = new Uint8Array(10000).fill(42);
        \\  const options = {
        \\    get stream() {
        \\      arr.buffer.transfer(0);
        \\      globalThis.reuse = new Uint8Array(10000).fill(90);
        \\      return false;
        \\    }
        \\  };
        \\  return decoder.decode(arr, options);
        \\})()
    , "");
}

test "decode() of an ArrayBuffer its options getter detaches reads no bytes" {
    try expectResult("ArrayBuffer detached by the options getter",
        \\(() => {
        \\  const decoder = new TextDecoder();
        \\  const buffer = new Uint8Array(10000).fill(42).buffer;
        \\  const options = { get stream() { buffer.transfer(0); return false; } };
        \\  return decoder.decode(buffer, options);
        \\})()
    , "");
}

test "decode() of a DataView its options getter detaches reads no bytes" {
    try expectResult("DataView detached by the options getter",
        \\(() => {
        \\  const decoder = new TextDecoder();
        \\  const view = new DataView(new Uint8Array(10000).fill(42).buffer, 1, 3);
        \\  const options = { get stream() { view.buffer.transfer(0); return false; } };
        \\  return decoder.decode(view, options);
        \\})()
    , "");
}

// A getter that writes into the input instead: step 3's copy is of the
// bytes as they are then.
test "decode() reads the input as the options getter left it" {
    try expectResult("input altered by the options getter",
        \\(() => {
        \\  const decoder = new TextDecoder();
        \\  const arr = new Uint8Array([104, 105]);
        \\  const options = { get stream() { arr[0] = 72; return false; } };
        \\  return decoder.decode(arr, options);
        \\})()
    , "Hi");
}

// A transfer that MOVES the bytes elsewhere (transfer() with no length keeps
// them in the new buffer): the input's own buffer is still detached.
test "decode() of a buffer transferred away keeps none of its bytes" {
    try expectResult("buffer transferred away by the options getter",
        \\(() => {
        \\  const decoder = new TextDecoder();
        \\  const arr = new Uint8Array([104, 105]);
        \\  const options = { get stream() { globalThis.moved = arr.buffer.transfer(); return false; } };
        \\  return decoder.decode(arr, options) + '|' + new TextDecoder().decode(moved);
        \\})()
    , "|hi");
}

// The streaming path: a detached input pushes nothing, and what an earlier
// call left pending is still decoded.
test "a streaming decode() keeps its pending bytes when the next input is detached" {
    try expectResult("streaming input detached by the options getter",
        \\(() => {
        \\  const decoder = new TextDecoder();
        \\  const first = decoder.decode(new Uint8Array([0xE2, 0x82]), { stream: true });
        \\  const arr = new Uint8Array([0xAC]);
        \\  const options = { get stream() { arr.buffer.transfer(0); return false; } };
        \\  return first + '|' + decoder.decode(arr, options);
        \\})()
    , "|\u{FFFD}");
}
