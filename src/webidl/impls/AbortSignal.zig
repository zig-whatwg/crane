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
    runtime.Instance.deinit(instance);
}

/// Getter for aborted
///
/// Spec: § 3.3.1 "The aborted getter steps are to return this's abort reason if it exists; otherwise false"
pub fn get_aborted(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.aborted;
}

/// Getter for reason
///
/// Spec: § 3.3.1 "The reason getter steps are to return this's abort reason"
/// Note: Returns InvalidState when reason is not set (undefined in JS)
pub fn get_reason(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    // Return reason (or InvalidState if not set - represents undefined)
    return internal.reason orelse return error.InvalidState;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onabort orelse return error.InvalidState;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onabort = value;
}

/// Static operation: any(signals)
///
/// Spec: § 3.3.2 "Returns a signal that is aborted when any of the given signals are aborted"
/// Note: Full implementation requires DOM event infrastructure
pub fn call__any(instance: *runtime.Instance, signals: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = signals;
    // Requires iteration over signals and event listener setup
    // For now, return NotImplemented as this needs full DOM event support
    return error.NotImplemented;
}

/// Static operation: abort(reason)
///
/// Spec: § 3.3.2 "Returns an immediately aborted signal"
/// "The static abort(reason) method steps are:
///  1. Let signal be a new AbortSignal object.
///  2. Set signal's abort reason to reason if it is given; otherwise to a new
///     "AbortError" DOMException.
///  3. Return signal."
pub fn call_abort(instance: *runtime.Instance, reason: *const anyopaque) ImplError!*runtime.Instance {
    // Get context and allocator from the passed instance
    // For static methods, this instance is a "template" that carries context
    const ctx = instance.ctx;
    const allocator = ctx.getAllocator();

    // Step 1: Create a new AbortSignal
    const new_signal = AbortSignal.init(allocator, ctx) catch return error.OutOfMemory;
    errdefer AbortSignal.deinit(new_signal);

    // Steps 2-3: Immediately signal abort with the reason
    // The signalAbort function handles setting aborted=true and the reason
    try signalAbort(new_signal, @constCast(reason));

    return new_signal;
}

/// Static operation: timeout(milliseconds)
///
/// Spec: § 3.3.2 "Returns a signal that will abort after the given milliseconds"
/// "The static timeout(milliseconds) method steps are:
///  1. Let signal be a new AbortSignal object.
///  2. Let global be signal's relevant global object.
///  3. Run steps after a timeout given global, "AbortSignal-timeout", milliseconds,
///     and the following step:
///       3.1 Queue a global task on the timer task source given global to signal
///           abort on signal given a new "TimeoutError" DOMException.
///  4. Return signal."
pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) ImplError!*runtime.Instance {
    // Get context and allocator from the passed instance
    const ctx = instance.ctx;
    const allocator = ctx.getAllocator();

    // Step 1: Create a new AbortSignal
    const new_signal = AbortSignal.init(allocator, ctx) catch return error.OutOfMemory;
    errdefer AbortSignal.deinit(new_signal);

    // Steps 2-3: Schedule timer to abort after milliseconds
    // Get timer interface from context
    const timer_interface = ctx.getTimer() catch {
        // If no timer support, we can't implement timeout - return the signal
        // but it won't actually timeout. Log a warning if possible.
        // For now, return the signal anyway (spec doesn't define error behavior)
        return new_signal;
    };

    // Create timer callback context
    // We need to store the signal pointer so the callback can abort it
    const CallbackContext = struct {
        signal: *runtime.Instance,
    };

    const callback_ctx = allocator.create(CallbackContext) catch return error.OutOfMemory;
    callback_ctx.* = .{ .signal = new_signal };

    // Schedule the timer
    // The callback will signal abort when the timer fires
    // setTimeout returns TimerId (always succeeds if timer interface is available)
    _ = timer_interface.setTimeout(
        milliseconds,
        timeoutCallback,
        @ptrCast(callback_ctx),
    );

    // Step 4: Return signal
    return new_signal;
}

/// Timer callback for AbortSignal.timeout()
/// Called when the timeout duration has elapsed
fn timeoutCallback(user_data: ?*anyopaque) void {
    const CallbackContext = struct {
        signal: *runtime.Instance,
    };

    const callback_ctx: *CallbackContext = @ptrCast(@alignCast(user_data orelse return));
    const signal = callback_ctx.signal;

    // Signal abort with a TimeoutError
    // In a full implementation, we'd create a DOMException with name="TimeoutError"
    // For now, we just signal abort with null reason (impl treats this as generic abort)
    signalAbort(signal, null) catch {
        // Abort failed - signal might already be aborted
    };

    // Clean up callback context
    // Note: We need the allocator to free this. Get it from the signal's context.
    const allocator = signal.ctx.getAllocator();
    allocator.destroy(callback_ctx);
}

/// Operation: throwIfAborted
///
/// Spec: § 3.3.3 "Throws this's abort reason if this is aborted"
pub fn call_throwIfAborted(instance: *runtime.Instance) ImplError!void {
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
