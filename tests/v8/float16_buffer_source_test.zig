//! Float16Array is an ArrayBufferView, and so a BufferSource (WebIDL 3.2.26:
//! ArrayBufferView = (Int8Array or ... or Float16Array or Float32Array or
//! Float64Array or DataView)), through every place the V8 adapter names a
//! view's kind: argument conversion, "get a copy of the bytes held by the
//! buffer source", engine.describeArrayBufferView, a union arm's
//! [[TypedArrayName]] and engine.createArrayBufferView.
//!
//! Float16Array exists only when V8 started with --js-float16array
//! (snapshot_loader.RUNTIME_V8_FLAGS, which engine.initializeEngine sets). In
//! the shared tests/v8 executable another file may have started V8 first
//! without it; these tests then skip, and -Dtest-file= or
//! -Dtest-isolation=file runs them.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const ffi = v8.ffi;
const conv = v8.conversions;
const iface = v8.interface_mod;
const BufferSource = iface.non_owning_arg_types.BufferSource;
const ArrayBufferView = iface.non_owning_arg_types.ArrayBufferView;
const testing_allocator = std.testing.allocator;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var data_once: ?*runtime.ContextData = null;

/// One isolate and realm for the file; V8 is never torn down here.
fn realm() !runtime.Context {
    if (data_once) |d| return d;
    try engine.initializeEngine(.{});
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    const data = try std.heap.page_allocator.create(runtime.ContextData);
    data.* = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context });
    data.agent = @ptrCast(i);
    isolate_once = i;
    context_once = context;
    data_once = data;
    return data;
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

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

/// The realm, or null (the test skips) when this process's V8 has no
/// Float16Array.
fn realmWithFloat16() !?runtime.Context {
    const r = try realm();
    if (try evalInt("typeof Float16Array === 'function' ? 1 : 0") == 1) return r;
    std.log.warn("skipping: V8 was started in this process without --js-float16array; run this file with -Dtest-file= or -Dtest-isolation=file", .{});
    return null;
}

/// new Float16Array([1, 2, -2, 0.5]).subarray(1, 3): bytes 2..6 of an
/// 8-byte buffer, [0x00 0x40 0x00 0xC0] (2 and -2 as binary16, little endian).
const window_code = "new Float16Array([1, 2, -2, 0.5]).subarray(1, 3)";
const window_bytes = [_]u8{ 0x00, 0x40, 0x00, 0xC0 };

test "a Float16Array converts to a BufferSource that refers to it, and copies its own window" {
    const r = (try realmWithFloat16()) orelse return;
    const handle = try eval(window_code);
    defer ffi.v8_Value_Dispose(handle);
    const source = try conv.fromV8Value(BufferSource, testing_allocator, isolate_once.?, context_once.?, handle);
    try std.testing.expect(source == .array_buffer_view);
    try std.testing.expect(source.array_buffer_view == .float16_array);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(handle)), source.jsHandle());
    try std.testing.expectEqual(@as(usize, 2), source.array_buffer_view.getByteOffset());
    try std.testing.expectEqual(@as(usize, 4), source.array_buffer_view.getByteLength());
    try std.testing.expectEqual(@as(?usize, 2), source.array_buffer_view.getArrayLength());
    try std.testing.expectEqual(@as(u8, 2), source.array_buffer_view.getElementSize());
    const bytes = (try engine.getCopyOfBufferSourceBytes(r, source.jsValue(runtime.JSValue).?, testing_allocator)).?;
    defer testing_allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &window_bytes, bytes);
}

test "a Float16Array converts to an ArrayBufferView, and one over a SharedArrayBuffer is a TypeError" {
    _ = (try realmWithFloat16()) orelse return;
    const handle = try eval(window_code);
    defer ffi.v8_Value_Dispose(handle);
    const view = try conv.fromV8Value(ArrayBufferView, testing_allocator, isolate_once.?, context_once.?, handle);
    try std.testing.expect(view == .float16_array);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(handle)), view.jsHandle());

    const shared = try eval("new Float16Array(new SharedArrayBuffer(4))");
    defer ffi.v8_Value_Dispose(shared);
    try std.testing.expectError(error.TypeError, conv.fromV8Value(BufferSource, testing_allocator, isolate_once.?, context_once.?, shared));
    try std.testing.expectError(error.TypeError, conv.fromV8Value(ArrayBufferView, testing_allocator, isolate_once.?, context_once.?, shared));
}

test "describeArrayBufferView names a Float16Array, and the union arm match knows its [[TypedArrayName]]" {
    const r = (try realmWithFloat16()) orelse return;
    const handle = try eval(window_code);
    defer ffi.v8_Value_Dispose(handle);
    const description = engine.describeArrayBufferView(r, runtime.JSValue.fromHandle(@ptrCast(handle))) orelse return error.NotDescribed;
    try std.testing.expectEqual(engine.ViewType.float16_array, description.view_type);
    try std.testing.expectEqual(@as(usize, 2), description.byte_offset);
    try std.testing.expectEqual(@as(usize, 4), description.byte_length);
    try std.testing.expect(!description.shared and !description.detached);
    try std.testing.expectEqual(@as(u64, 2), engine.ViewType.float16_array.elementSize());
    try std.testing.expectEqualStrings("Float16Array", conv.typedArrayNameOf(handle) orelse return error.NoName);
}

test "createArrayBufferView makes a Float16Array over a buffer" {
    const r = (try realmWithFloat16()) orelse return;
    const buffer = try eval("globalThis.f16buffer = new Uint8Array([0, 0, 0, 0x40, 0, 0xC0]).buffer; f16buffer");
    defer ffi.v8_Value_Dispose(buffer);
    // Two elements from byte 2: 2 and -2.
    const made = try engine.createArrayBufferView(r, .float16_array, runtime.JSValue.fromHandle(@ptrCast(buffer)), 2, 2);
    defer made.release();
    const description = engine.describeArrayBufferView(r, made.borrow()) orelse return error.NotDescribed;
    try std.testing.expectEqual(engine.ViewType.float16_array, description.view_type);
    try std.testing.expectEqual(@as(usize, 4), description.byte_length);
    const bytes = (try engine.getCopyOfBufferSourceBytes(r, made.borrow(), testing_allocator)).?;
    defer testing_allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &window_bytes, bytes);
    // A misaligned offset does not fit a 2-byte element.
    try std.testing.expectError(error.OperationFailed, engine.createArrayBufferView(r, .float16_array, runtime.JSValue.fromHandle(@ptrCast(buffer)), 1, 1));
}

test "every other typed array kind still converts and is described as before" {
    const r = try realm();
    const cases = [_]struct { code: []const u8, view_type: engine.ViewType }{
        .{ .code = "new Int8Array(2)", .view_type = .int8_array },
        .{ .code = "new Uint8Array(2)", .view_type = .uint8_array },
        .{ .code = "new Uint8ClampedArray(2)", .view_type = .uint8_clamped_array },
        .{ .code = "new Int16Array(2)", .view_type = .int16_array },
        .{ .code = "new Uint16Array(2)", .view_type = .uint16_array },
        .{ .code = "new Int32Array(2)", .view_type = .int32_array },
        .{ .code = "new Uint32Array(2)", .view_type = .uint32_array },
        .{ .code = "new Float32Array(2)", .view_type = .float32_array },
        .{ .code = "new Float64Array(2)", .view_type = .float64_array },
        .{ .code = "new BigInt64Array(2)", .view_type = .bigint64_array },
        .{ .code = "new BigUint64Array(2)", .view_type = .biguint64_array },
        .{ .code = "new DataView(new ArrayBuffer(2))", .view_type = .data_view },
    };
    for (cases) |case| {
        const handle = try eval(case.code);
        defer ffi.v8_Value_Dispose(handle);
        const description = engine.describeArrayBufferView(r, runtime.JSValue.fromHandle(@ptrCast(handle))) orelse return error.NotDescribed;
        try std.testing.expectEqual(case.view_type, description.view_type);
        try std.testing.expectEqual(@as(usize, @intCast(case.view_type.elementSize() * 2)), description.byte_length);
        _ = try conv.fromV8Value(BufferSource, testing_allocator, isolate_once.?, context_once.?, handle);
    }
}
