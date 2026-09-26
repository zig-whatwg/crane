//! ArrayBufferViews an impl takes unconverted - the V8 side of the Engine
//! table's describeArrayBufferView and writeIntoArrayBufferView (AGENTS.md,
//! "The engine boundary").
//!
//! A view arrives as a runtime.JSValue `.handle`; nothing here keeps it past
//! the call, and every V8 handle made along the way is released here.

const runtime = @import("runtime");
const EngineError = runtime.EngineError;
const JSValue = runtime.JSValue;
const ViewType = runtime.arraybuffer_view.ViewType;

const ffi = @import("ffi.zig");

/// The V8 value a JSValue carries, when it is an object handle.
fn handleOf(value: JSValue) ?*ffi.Value {
    return switch (value) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        else => null,
    };
}

fn viewTypeOf(kind: ffi.ViewKind) ViewType {
    return switch (kind) {
        .int8 => .int8_array,
        .uint8 => .uint8_array,
        .uint8_clamped => .uint8_clamped_array,
        .int16 => .int16_array,
        .uint16 => .uint16_array,
        .int32 => .int32_array,
        .uint32 => .uint32_array,
        .float32 => .float32_array,
        .float64 => .float64_array,
        .bigint64 => .bigint64_array,
        .biguint64 => .biguint64_array,
        .data_view => .data_view,
    };
}

/// The ArrayBufferView `value` is, or null for anything else.
pub fn describeArrayBufferView(value: JSValue) ?runtime.ArrayBufferViewDescription {
    const view = handleOf(value) orelse return null;
    var info: ffi.ViewInfo = undefined;
    if (!ffi.v8_ArrayBufferView_Describe(view, &info)) return null;
    return .{
        .view_type = viewTypeOf(info.kind),
        .byte_offset = info.byte_offset,
        .byte_length = info.byte_length,
        .detached = info.buffer_detached,
        .shared = info.buffer_shared,
    };
}

/// WebIDL "write" `bytes` into the view, `starting_offset` bytes in.
pub fn writeIntoArrayBufferView(view: JSValue, bytes: []const u8, starting_offset: usize) EngineError!void {
    const target = handleOf(view) orelse return EngineError.TypeError;
    if (!ffi.v8_Value_IsArrayBufferView(target)) return EngineError.TypeError;
    if (!ffi.v8_ArrayBufferView_WriteBytes(target, bytes.ptr, bytes.len, starting_offset)) return EngineError.OperationFailed;
}
