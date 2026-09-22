//! TransformStreamDefaultController Implementation
//!
//! WHATWG Streams Standard § 6.3: https://streams.spec.whatwg.org/#ts-default-controller-class
//!
//! The IDL surface only; the slots and algorithms are in `streams_transform.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const js = @import("streams_js.zig");
const st = @import("streams_transform.zig");

pub const State = interfaces.TransformStreamDefaultController.State;
pub const InternalState = st.Controller;

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

/// `desiredSize` - § 6.3.3.
pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
    _ = st.controllerOf(instance) orelse return error.TypeError;
    return st.controllerDesiredSize(instance);
}

/// `enqueue(chunk)` - § 6.3.3: Perform ? TransformStreamDefaultControllerEnqueue(this, chunk).
pub fn call_enqueue(instance: *runtime.Instance, chunk: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = st.controllerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    const value = try realm.fromOptional(chunk);
    defer js.dispose(value);
    if (try st.controllerEnqueueCompletion(realm, instance, value)) |e| {
        defer js.dispose(e);
        return realm.throwValue(e);
    }
}

/// `error(e)` - § 6.3.3: Perform ? TransformStreamDefaultControllerError(this, e).
pub fn call_error(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = st.controllerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    const e = try realm.fromOptional(reason);
    defer js.dispose(e);
    st.controllerError(realm, instance, e);
}

/// `terminate()` - § 6.3.3: Perform ? TransformStreamDefaultControllerTerminate(this).
pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
    _ = st.controllerOf(instance) orelse return error.TypeError;
    try st.controllerTerminate(try js.Realm.of(instance), instance);
}
