//! ReadableStreamDefaultController Implementation
//!
//! WHATWG Streams Standard § 4.6: https://streams.spec.whatwg.org/#rs-default-controller-class
//!
//! The IDL surface only; the slots and algorithms are in `streams_readable.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");

pub const State = interfaces.ReadableStreamDefaultController.State;
pub const InternalState = srd.DefaultController;

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

/// `desiredSize` - § 4.6.3.
pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
    const c = srd.defaultControllerOf(instance) orelse return error.TypeError;
    return srd.defaultGetDesiredSize(c);
}

/// `close()` - § 4.6.3.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const c = srd.defaultControllerOf(instance) orelse return error.TypeError;
    // Step 1: a stream that cannot close is a TypeError.
    if (!srd.defaultCanCloseOrEnqueue(c)) return error.TypeError;
    // Step 2
    srd.defaultControllerClose(try js.Realm.of(instance), instance);
}

/// `enqueue(chunk)` - § 4.6.3.
pub fn call_enqueue(instance: *runtime.Instance, chunk: webidl.Opt(runtime.JSValue)) anyerror!void {
    const c = srd.defaultControllerOf(instance) orelse return error.TypeError;
    // Step 1: a stream that cannot enqueue is a TypeError.
    if (!srd.defaultCanCloseOrEnqueue(c)) return error.TypeError;
    // Step 2: Perform ? ReadableStreamDefaultControllerEnqueue(this, chunk).
    const realm = try js.Realm.of(instance);
    const value = try realm.fromOptional(chunk);
    defer js.dispose(value);
    try srd.defaultControllerEnqueue(realm, instance, value);
}

/// `error(e)` - § 4.6.3.
pub fn call_error(instance: *runtime.Instance, e: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = srd.defaultControllerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    const err = try realm.fromOptional(e);
    defer js.dispose(err);
    srd.defaultControllerError(realm, instance, err);
}
