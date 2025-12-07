//! Implementation for AbortSignal interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-abortsignal
//!
//! AbortSignal represents a signal that can be used to abort operations.
//! When an AbortController's abort() method is called, its signal becomes aborted.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const AbortSignal = interfaces.AbortSignal;

pub const State = AbortSignal.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
    AbortError,
};

/// Internal state for AbortSignal
///
/// Spec: https://dom.spec.whatwg.org/#abortsignal
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// [[aborted]]: Whether the signal is aborted
    aborted: bool,

    /// [[reason]]: The abort reason (null if not aborted or no reason provided)
    reason: ?*anyopaque,

    /// [[onabort]]: Event handler for abort event (stub for now)
    onabort: ?typedefs.EventHandler,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // reason is borrowed, not owned
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

    const internal = state.own._internal.?;
    internal.allocator = allocator;
    internal.aborted = false;
    internal.reason = null;
    internal.onabort = null;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for aborted
///
/// Spec: § 3.3.1 "The aborted getter steps are to return this's abort reason if it exists; otherwise false"
pub fn get_aborted(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.aborted;
}

/// Getter for reason
///
/// Spec: § 3.3.1 "The reason getter steps are to return this's abort reason"
/// Note: Returns undefined JSValue when reason is not set
pub fn get_reason(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    // Convert anyopaque to JSValue, or return undefined if not set
    if (internal.reason) |reason| {
        return runtime.JSValue.fromAnyopaque(reason);
    }
    return runtime.JSValue.jsUndefined;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onabort orelse return error.InvalidState;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onabort = value;
}

/// Static operation: any(signals)
///
/// Spec: § 3.3.2 "Returns a signal that is aborted when any of the given signals are aborted"
/// Note: Full implementation requires DOM event infrastructure
pub fn call__any(instance: *runtime.Instance, signals: *const anyopaque) anyerror!*runtime.Instance {
    _ = instance;
    _ = signals;
    // Requires iteration over signals and event listener setup
    // For now, return NotImplemented as this needs full DOM event support
    return error.NotImplemented;
}

/// Static operation: abort(reason)
///
/// Spec: § 3.3.2 "Returns an immediately aborted signal"
pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = instance;
    _ = reason;
    // Static method that creates a new AbortSignal and immediately aborts it
    // Requires access to allocator from static context
    return error.NotImplemented;
}

/// Static operation: timeout(milliseconds)
///
/// Spec: § 3.3.2 "Returns a signal that will abort after the given milliseconds"
pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) anyerror!*runtime.Instance {
    _ = instance;
    _ = milliseconds;
    // Requires timer/scheduling infrastructure
    return error.NotImplemented;
}

/// Operation: throwIfAborted
///
/// Spec: § 3.3.3 "Throws this's abort reason if this is aborted"
pub fn call_throwIfAborted(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.aborted) {
        return error.AbortError;
    }
}

// ============================================================================
// Internal Helper Functions (for AbortController)
// ============================================================================

/// Signal abort - called by AbortController.abort()
///
/// Spec: § 3.3 "To signal abort on an AbortSignal signal, given an optional reason"
pub fn signalAbort(instance: *runtime.Instance, reason: ?*anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // If already aborted, do nothing
    if (internal.aborted) {
        return;
    }

    // Set aborted to true
    internal.aborted = true;

    // Set reason (or default to AbortError if not provided)
    internal.reason = reason;

    // Fire abort event (requires DOM event infrastructure)
    // For now, just set the flag - event firing would happen here
}
