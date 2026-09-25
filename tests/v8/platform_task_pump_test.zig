//! A turn of `V8EventLoop.runOnceBlocking` runs the foreground tasks V8 has
//! posted to the platform for its isolate.
//!
//! V8 does part of its work on the embedder's thread through
//! `v8::platform::PumpMessageLoop`: an asynchronous WebAssembly compile
//! finishes on a background thread and posts the task that resolves its
//! promise, and FinalizationRegistry cleanup is a posted task too. Nothing in
//! Crane pumped, so `WebAssembly.compile(bytes)` returned a promise that never
//! settled. d8's `ProcessMessages` is the model: pump, then a microtask
//! checkpoint after every task that ran.

const std = @import("std");
const clock = @import("clock");
const v8 = @import("v8");
const ffi = v8.ffi;

/// A live isolate with an entered context, one for the whole file, as in
/// event_loop_turn_test.zig - V8 is never torn down here.
var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;

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

fn run(i: *ffi.Isolate, source: []const u8) !*ffi.Value {
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, source.ptr, @intCast(source.len)) orelse return error.StringFailed;
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
}

fn settled(i: *ffi.Isolate) !i32 {
    const value = try run(i, "globalThis.settled");
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

test "a WebAssembly.compile promise settles within the event loop's turns" {
    const i = try isolate();
    var loop = v8.V8EventLoop.initWithoutTimers(i, std.testing.allocator);
    defer loop.deinit();

    // (module (func (export "inc") (param i32) (result i32)
    //   local.get 0 i32.const 1 i32.add))
    const started = try run(i,
        \\globalThis.settled = 0;
        \\WebAssembly.compile(new Uint8Array([
        \\  0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x01, 0x60,
        \\  0x01, 0x7f, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07, 0x01, 0x03,
        \\  0x69, 0x6e, 0x63, 0x00, 0x00, 0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00,
        \\  0x41, 0x01, 0x6a, 0x0b])).then(
        \\  m => { globalThis.settled = m instanceof WebAssembly.Module ? 1 : 2; },
        \\  () => { globalThis.settled = 3; });
    );
    ffi.v8_Value_Dispose(started);

    // The compile runs on a background thread; give it up to five seconds of
    // turns. A pumping loop settles it in the first few.
    var turns: usize = 0;
    while (turns < 500 and try settled(i) == 0) : (turns += 1) {
        _ = loop.runOnceBlocking(0);
        clock.sleep(10 * std.time.ns_per_ms);
    }
    try std.testing.expectEqual(@as(i32, 1), try settled(i));
}
