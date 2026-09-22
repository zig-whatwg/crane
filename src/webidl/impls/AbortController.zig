//! Implementation for AbortController interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-abortcontroller
//!
//! AbortController provides a way to abort one or more web requests.
//! When abort() is called, the controller's signal is aborted.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const AbortController = interfaces.AbortController;
const same_object = @import("same_object.zig");

pub const State = AbortController.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for AbortController
///
/// Spec: https://dom.spec.whatwg.org/#abortcontroller
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// [[signal]]: The associated AbortSignal, created with the controller.
    signal: *runtime.Instance,

    /// Holds the signal's wrapper once the signal has been handed to script,
    /// which also means the wrapper cache owns the signal from then on - see
    /// `deinit` and `same_object.zig`.
    signal_pin: same_object.Pin,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        if (self.signal_pin.isHeld()) {
            // Script has seen the signal, so V8's wrapper cache owns it and
            // frees it when its wrapper goes - which may be long after this
            // controller: `const s = new AbortController().signal`.
            //
            // This used to deinit the signal here unconditionally, on the
            // premise (in a comment) that a signal made by init() is never in
            // the wrapper cache. Every `controller.signal` read put it there.
            // So a collected controller freed a signal script still held, and
            // a collected signal left the controller pointing into the slab.
            self.signal_pin.release();
        } else {
            // Never handed out - nothing else will ever free it.
            interfaces.AbortSignal.deinit(self.signal);
        }
        allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);
    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    // Create the associated AbortSignal
    const signal = try interfaces.AbortSignal.init(allocator, ctx);
    errdefer interfaces.AbortSignal.deinit(signal);

    const internal = state.own._internal.?;
    internal.allocator = allocator;
    internal.signal = signal;
    internal.signal_pin = .{};

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // Clean up the owned signal and internal state
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: § 3.2.1 "The AbortController() constructor steps are:"
/// 1. Let signal be a new AbortSignal object
/// 2. Set this's signal to signal
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init() which handles signal creation
    const instance = try init(ctx.allocator, State, &AbortController.vtable, ctx);
    errdefer deinit(instance);

    return instance;
}

/// Getter for signal
///
/// Spec: § 3.2.2 "The signal getter steps are to return this's signal"
pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    // [SameObject], and the signal carries `onabort` and its listeners: keep
    // its wrapper for as long as this controller lives.
    internal.signal_pin.hold(internal.signal);
    return internal.signal;
}

/// Operation: abort
///
/// Spec: § 3.2.3 "The abort(reason) method steps are to signal abort on this's signal with reason"
pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Signal abort on the associated signal
    // Per DOM spec, reason is typed as `any` which maps to runtime.JSValue
    const AbortSignalImpl = @import("AbortSignal.zig");
    const reason_value: runtime.JSValue = if (reason.was_passed)
        reason.value
    else
        runtime.JSValue.jsUndefined;
    AbortSignalImpl.signalAbort(internal.signal, reason_value) catch |err| {
        return switch (err) {
            error.InvalidState => error.InvalidState,
            else => error.InvalidState,
        };
    };
}
