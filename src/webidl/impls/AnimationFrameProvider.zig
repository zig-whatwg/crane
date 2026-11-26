//! Implementation for the AnimationFrameProvider mixin (HTML §8.9):
//! requestAnimationFrame() and cancelAnimationFrame(), shared by Window and
//! DedicatedWorkerGlobalScope.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const callbacks = @import("callbacks");
const dom = @import("dom");
const html = @import("html");
const AnimationFrameProvider = interfaces.AnimationFrameProvider;

pub const State = AnimationFrameProvider.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

pub const InternalState = struct {};

/// Operation: requestAnimationFrame (HTML §8.9).
pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: callbacks.FrameRequestCallback) anyerror!u32 {
    if (instance.stateAs(interfaces.DedicatedWorkerGlobalScope.State) != null) {
        return html.worker_host.requestAnimationFrame(instance.ctx, callback.keep());
    }
    if (!dom.window_globals.hasInternal(instance)) return error.InvalidStateError;
    // Window's requestAnimationFrame is bound natively on the global object.
    return 0;
}

/// Operation: cancelAnimationFrame (HTML §8.9).
pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
    if (instance.stateAs(interfaces.DedicatedWorkerGlobalScope.State) != null) {
        return html.worker_host.cancelAnimationFrame(instance.ctx, handle);
    }
    if (!dom.window_globals.hasInternal(instance)) return error.InvalidStateError;
    // Bound natively on Window, as requestAnimationFrame is.
}
