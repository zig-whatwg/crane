//! ReadableStreamBYOBRequest Implementation
//!
//! WHATWG Streams Standard § 4.8: https://streams.spec.whatwg.org/#rs-byob-request-class
//!
//! The IDL surface only; the slots and algorithms are in `streams_readable.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");

pub const State = interfaces.ReadableStreamBYOBRequest.State;
pub const InternalState = srd.ByobRequest;

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

/// `view` - § 4.8.3: Return this.[[view]]. The request keeps the handle.
pub fn get_view(instance: *runtime.Instance) anyerror!?typedefs.ArrayBufferView {
    const request = srd.byobRequestOf(instance) orelse return error.TypeError;
    const view = request.view orelse return null;
    const info = js.describeView(view) orelse return null;
    return typedefs.ArrayBufferView.fromEngine(@intCast(@intFromEnum(info.kind)), info.byte_offset, info.length, view);
}

/// `respond(bytesWritten)` - § 4.8.3.
pub fn call_respond(instance: *runtime.Instance, bytesWritten: u64) anyerror!void {
    const request = srd.byobRequestOf(instance) orelse return error.TypeError;
    // Step 1: an invalidated request is a TypeError.
    const controller = request.controller orelse return error.TypeError;
    // Step 2: so is one whose buffer was detached.
    const view = request.view orelse return error.TypeError;
    const info = js.describeView(view) orelse return error.TypeError;
    if (info.buffer_detached) return error.TypeError;
    // Step 5: Perform ? ReadableByteStreamControllerRespond(controller, bytesWritten).
    try srd.byteRespond(try js.Realm.of(instance), controller, bytesWritten);
}

/// `respondWithNewView(view)` - § 4.8.3.
pub fn call_respondWithNewView(instance: *runtime.Instance, view: typedefs.ArrayBufferView) anyerror!void {
    const view_js: js.Value = @ptrCast(@alignCast(view.jsHandle() orelse return error.TypeError));
    defer js.dispose(view_js);
    const request = srd.byobRequestOf(instance) orelse return error.TypeError;
    // Step 1
    const controller = request.controller orelse return error.TypeError;
    // Step 2: a detached view is a TypeError.
    const info = js.describeView(view_js) orelse return error.TypeError;
    if (info.buffer_detached) return error.TypeError;
    // Step 3: Return ? ReadableByteStreamControllerRespondWithNewView(controller, view).
    try srd.byteRespondWithNewView(try js.Realm.of(instance), controller, view_js);
}
