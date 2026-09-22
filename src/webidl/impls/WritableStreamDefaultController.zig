//! WritableStreamDefaultController Implementation
//!
//! WHATWG Streams Standard § 5.4: https://streams.spec.whatwg.org/#ws-default-controller-class
//!
//! The IDL surface only; the slots and algorithms are in `streams_writable.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const WritableStreamDefaultController = interfaces.WritableStreamDefaultController;
const js = @import("streams_js.zig");
const sw = @import("streams_writable.zig");

pub const State = WritableStreamDefaultController.State;
pub const InternalState = sw.Controller;

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

/// `signal` - § 5.4.3: Return this.[[abortController]]'s signal.
pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const controller = sw.controllerOf(instance) orelse return error.TypeError;
    const abort_controller = controller.abort_controller orelse return error.InvalidStateError;
    return interfaces.AbortController.get_signal(abort_controller);
}

/// `error(e)` - § 5.4.3.
pub fn call_error(instance: *runtime.Instance, e: webidl.Opt(runtime.JSValue)) anyerror!void {
    const controller = sw.controllerOf(instance) orelse return error.TypeError;
    // Steps 1-2: Only a writable stream is errored.
    if (sw.streamOf(controller.stream).?.state != .writable) return;
    // Step 3: Perform ! WritableStreamDefaultControllerError(this, e).
    const realm = try js.Realm.of(instance);
    const err = try realm.fromOptional(e);
    defer js.dispose(err);
    sw.controllerError(realm, instance, err);
}
