//! ReadableByteStreamController Implementation
//!
//! WHATWG Streams Standard § 4.7: https://streams.spec.whatwg.org/#rbs-controller-class
//!
//! The IDL surface only; the slots and algorithms are in `streams_readable.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");

pub const State = interfaces.ReadableByteStreamController.State;
pub const InternalState = srd.ByteController;

pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |slots| {
        state.own._internal = null;
        slots.deinit();
    }
}

/// `byobRequest` - § 4.7.3: Return ! ReadableByteStreamControllerGetBYOBRequest(this).
pub fn get_byobRequest(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = srd.byteControllerOf(instance) orelse return error.TypeError;
    return srd.byteGetByobRequest(try js.Realm.of(instance), instance);
}

/// `desiredSize` - § 4.7.3.
pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
    const c = srd.byteControllerOf(instance) orelse return error.TypeError;
    return srd.byteGetDesiredSize(c);
}

/// `enqueue(chunk)` - § 4.7.3.
pub fn call_enqueue(instance: *runtime.Instance, chunk: typedefs.ArrayBufferView) anyerror!void {
    const chunk_js: js.Value = @ptrCast(@alignCast(chunk.jsHandle() orelse return error.TypeError));
    defer js.dispose(chunk_js);
    const c = srd.byteControllerOf(instance) orelse return error.TypeError;
    const info = js.describeView(chunk_js) orelse return error.TypeError;
    // Steps 1-2: an empty chunk or an empty buffer.
    if (info.byte_length == 0) return error.TypeError;
    if (info.buffer_byte_length == 0) return error.TypeError;
    // Steps 3-4: a stream closing or not readable.
    if (c.close_requested) return error.TypeError;
    if (srd.streamOf(c.stream).?.state != .readable) return error.TypeError;
    // Step 5: Return ? ReadableByteStreamControllerEnqueue(this, chunk).
    try srd.byteControllerEnqueue(try js.Realm.of(instance), instance, chunk_js);
}

/// `close()` - § 4.7.3.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const c = srd.byteControllerOf(instance) orelse return error.TypeError;
    // Steps 1-2
    if (c.close_requested) return error.TypeError;
    if (srd.streamOf(c.stream).?.state != .readable) return error.TypeError;
    // Step 3: Perform ? ReadableByteStreamControllerClose(this).
    try srd.byteControllerClose(try js.Realm.of(instance), instance);
}

/// `error(e)` - § 4.7.3.
pub fn call_error(instance: *runtime.Instance, e: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = srd.byteControllerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    const err = try realm.fromOptional(e);
    defer js.dispose(err);
    srd.byteControllerError(realm, instance, err);
}
