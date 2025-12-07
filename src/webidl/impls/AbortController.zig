//! Implementation for AbortController interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-abortcontroller
//!
//! AbortController provides a way to abort one or more web requests.
//! When abort() is called, the controller's signal is aborted.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const AbortController = interfaces.AbortController;

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

    /// [[signal]]: The associated AbortSignal
    signal: *runtime.Instance,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Signal has its own lifecycle
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

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // Signal is managed separately (may be retained by user code)
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
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init() which handles signal creation
    const instance = try init(allocator, State, &AbortController.vtable, ctx);
    errdefer deinit(instance);

    return instance;
}

/// Getter for signal
///
/// Spec: § 3.2.2 "The signal getter steps are to return this's signal"
pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.signal;
}

/// Operation: abort
///
/// Spec: § 3.2.3 "The abort(reason) method steps are to signal abort on this's signal with reason"
pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(v8.JSValue)) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Signal abort on the associated signal
    const AbortSignalImpl = @import("AbortSignal.zig");
    const reason_ptr = if (reason.was_passed) @constCast(reason.value) else null;
    AbortSignalImpl.signalAbort(internal.signal, reason_ptr) catch |err| {
        return switch (err) {
            error.InvalidState => error.InvalidState,
            else => error.InvalidState,
        };
    };
}
