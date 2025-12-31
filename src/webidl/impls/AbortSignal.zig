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

/// Abort algorithm callback - called when signal aborts
/// The callback receives user data and should set an atomic flag or similar
pub const AbortCallback = struct {
    callback: *const fn (data: ?*anyopaque) void,
    data: ?*anyopaque,
};

/// Internal state for AbortSignal
///
/// Spec: https://dom.spec.whatwg.org/#abortsignal
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// [[aborted]]: Whether the signal is aborted
    aborted: bool,

    /// [[reason]]: The abort reason (undefined if not aborted or no reason provided)
    /// Per DOM spec, `reason` is typed as `any` which maps to runtime.JSValue
    reason: runtime.JSValue,

    /// [[onabort]]: Event handler for abort event (stub for now)
    onabort: ?typedefs.EventHandler,

    /// Timer ID for timeout signals (used for cancellation)
    timer_id: ?runtime.timer.TimerId = null,

    /// [[abort algorithms]]: List of callbacks to run when signal aborts
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-abort-algorithms
    abort_algorithms: std.ArrayListUnmanaged(AbortCallback) = .{},

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.abort_algorithms.deinit(allocator);
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
    internal.reason = runtime.JSValue.jsUndefined;
    internal.onabort = null;
    internal.timer_id = null;
    internal.abort_algorithms = .{};

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
    return internal.reason;
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
/// Static methods use call_static_<name> convention (_any has underscore prefix in IDL)
pub fn call_static__any(instance: *runtime.Instance, signals: runtime.JSValue) anyerror!*runtime.Instance {
    _ = instance;
    _ = signals;
    // Requires iteration over signals and event listener setup
    // For now, return NotImplemented as this needs full DOM event support
    return error.NotImplemented;
}

/// Static operation: abort(reason)
///
/// Spec: § 3.3.2 "The abort(reason) static method steps are:"
/// 1. Let signal be a new AbortSignal object.
/// 2. Set signal's abort reason to reason if it is given; otherwise to a new "AbortError" DOMException.
/// 3. Return signal.
///
/// Note: This creates a pre-aborted signal. The abort event is NOT fired because
/// the signal was never in a non-aborted state.
pub fn call_static_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    const ctx = instance.ctx;
    const allocator = ctx.allocator;

    // 1. Let signal be a new AbortSignal object
    const signal = try init(allocator, State, &interfaces.AbortSignal.vtable, ctx);
    errdefer deinit(signal);

    const state = signal.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Set aborted to true (pre-aborted signal)
    internal.aborted = true;

    // 2. Set signal's abort reason to reason if given; otherwise to a new "AbortError" DOMException
    if (reason.was_passed and !reason.value.isUndefined()) {
        internal.reason = reason.value;
    } else {
        // Create AbortError DOMException as default reason
        const abort_error = try createAbortError(ctx);
        internal.reason = runtime.JSValue.fromInstance(abort_error);
    }

    // 3. Return signal
    return signal;
}

/// Static operation: timeout(milliseconds)
///
/// Spec: § 3.3.2 "The timeout(milliseconds) static method steps are:"
/// 1. Let signal be a new AbortSignal object.
/// 2. Let global be signal's relevant global object.
/// 3. Run steps after a timeout given global, "AbortSignal-timeout", milliseconds, and the following step:
///    - Queue a global task on the timer task source given global to signal abort given signal
///      and a new "TimeoutError" DOMException.
/// 4. Return signal.
pub fn call_static_timeout(instance: *runtime.Instance, milliseconds: u64) anyerror!*runtime.Instance {
    const ctx = instance.ctx;
    const allocator = ctx.allocator;

    // Step 1: Let signal be a new AbortSignal object
    const signal = try init(allocator, State, &interfaces.AbortSignal.vtable, ctx);
    errdefer deinit(signal);

    // Step 2-3: Get timer interface and schedule timeout
    const timer = ctx.getTimer() catch {
        // No timer support - return signal that will never abort
        // This is a fallback for environments without timer support
        return signal;
    };

    // Create callback context that will be passed to the timer
    const callback_ctx = try allocator.create(TimeoutCallbackContext);
    errdefer allocator.destroy(callback_ctx);

    callback_ctx.* = .{
        .signal = signal,
        .allocator = allocator,
    };

    // Schedule the timer - when it fires, it will abort the signal with TimeoutError
    const timer_id = timer.setTimeout(milliseconds, timeoutTimerCallback, callback_ctx);

    // Store timer ID in internal state for potential cancellation
    const state = signal.getState(State);
    if (state.own._internal) |internal| {
        internal.timer_id = timer_id;
    }

    // Step 4: Return signal
    return signal;
}

/// Context passed to timeout timer callback
const TimeoutCallbackContext = struct {
    signal: *runtime.Instance,
    allocator: std.mem.Allocator,
};

/// Timer callback for AbortSignal.timeout()
/// Called when the timeout expires - aborts the signal with TimeoutError
fn timeoutTimerCallback(user_data: ?*anyopaque) void {
    const callback_ctx: *TimeoutCallbackContext = @ptrCast(@alignCast(user_data orelse return));
    defer callback_ctx.allocator.destroy(callback_ctx);

    const signal = callback_ctx.signal;
    const ctx = signal.ctx;

    // Create TimeoutError DOMException as the abort reason
    const timeout_error = createTimeoutError(ctx) catch {
        // If we can't create the error, abort with undefined reason
        signalAbort(signal, runtime.JSValue.jsUndefined) catch {};
        return;
    };

    // Signal abort with TimeoutError
    signalAbort(signal, runtime.JSValue.fromInstance(timeout_error)) catch {};
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

/// Create an AbortError DOMException
/// Per DOM spec: "AbortError" indicates the operation was aborted
fn createAbortError(ctx: runtime.Context) !*runtime.Instance {
    return try interfaces.DOMException.call_constructor(
        ctx,
        webidl.Opt(runtime.DOMString).passed(try runtime.DOMString.initDupe(ctx.allocator, "The operation was aborted.")),
        webidl.Opt(runtime.DOMString).passed(try runtime.DOMString.initDupe(ctx.allocator, "AbortError")),
    );
}

/// Create a TimeoutError DOMException
/// Per DOM spec: "TimeoutError" indicates the operation timed out
fn createTimeoutError(ctx: runtime.Context) !*runtime.Instance {
    return try interfaces.DOMException.call_constructor(
        ctx,
        webidl.Opt(runtime.DOMString).passed(try runtime.DOMString.initDupe(ctx.allocator, "The operation timed out.")),
        webidl.Opt(runtime.DOMString).passed(try runtime.DOMString.initDupe(ctx.allocator, "TimeoutError")),
    );
}

/// Signal abort - called by AbortController.abort()
///
/// Spec: § 3.3 "To signal abort on an AbortSignal signal, given an optional reason"
/// Algorithm:
/// 1. If signal is aborted, then return.
/// 2. Set signal's abort reason to reason if it is given; otherwise to a new "AbortError" DOMException.
/// 3. Let dependentSignalsToAbort be a new list.
/// 4. For each dependentSignal of signal's dependent signals: ... (TODO: dependent signals)
/// 5. Run the abort steps for signal.
/// 6. For each dependentSignal of dependentSignalsToAbort: run the abort steps for dependentSignal.
///
/// "Run the abort steps" for a signal:
/// 1. For each algorithm of signal's abort algorithms: run algorithm.
/// 2. Empty signal's abort algorithms.
/// 3. Fire an event named "abort" at signal.
pub fn signalAbort(instance: *runtime.Instance, reason: runtime.JSValue) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const ctx = instance.ctx;

    // Step 1: If signal is aborted, then return.
    if (internal.aborted) {
        return;
    }

    // Step 2: Set signal's abort reason to reason if given; otherwise to a new "AbortError" DOMException.
    internal.aborted = true;

    if (reason.isUndefined()) {
        // Create an AbortError DOMException as default reason
        const abort_error = createAbortError(ctx) catch {
            // If we can't create the DOMException, use undefined as fallback
            internal.reason = runtime.JSValue.jsUndefined;
            return;
        };
        internal.reason = runtime.JSValue.fromInstance(abort_error);
    } else {
        internal.reason = reason;
    }

    // Steps 3-4: TODO: Handle dependent signals (for AbortSignal.any())

    // Step 5: Run the abort steps for signal
    // Event firing is best-effort - errors are silently ignored
    runAbortSteps(instance) catch {};

    // Step 6: TODO: Run abort steps for dependent signals
}

/// Run the abort steps for an AbortSignal
/// Spec: § 3.3 "run the abort steps"
/// 1. For each algorithm of signal's abort algorithms: run algorithm.
/// 2. Empty signal's abort algorithms.
/// 3. Fire an event named "abort" at signal.
fn runAbortSteps(instance: *runtime.Instance) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Steps 1-2: Run and empty abort algorithms
    for (internal.abort_algorithms.items) |algo| {
        algo.callback(algo.data);
    }
    internal.abort_algorithms.clearRetainingCapacity();

    // Step 3: Fire an event named "abort" at signal
    try fireAbortEvent(instance);
}

/// Fire the "abort" event at the signal
/// Per DOM spec, this is a simple event (not bubbling, not cancelable)
fn fireAbortEvent(instance: *runtime.Instance) !void {
    const ctx = instance.ctx;

    // Create "abort" event with default EventInit (bubbles=false, cancelable=false)
    var event_type = try runtime.DOMString.initDupe(ctx.allocator, "abort");
    defer event_type.deinit(ctx.allocator);

    const event = try interfaces.Event.call_constructor(
        ctx,
        event_type,
        webidl.Opt(dictionaries.EventInit).notPassed(), // Use defaults
    );
    // Note: Event will be cleaned up by GC after dispatch

    // Dispatch the event to this signal (AbortSignal inherits from EventTarget)
    _ = try interfaces.EventTarget.call_dispatchEvent(instance, event);
}

pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = instance;
    _ = reason;
    return error.NotImplemented;
}

pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) anyerror!*runtime.Instance {
    _ = instance;
    _ = milliseconds;
    return error.NotImplemented;
}

pub fn call__any(instance: *runtime.Instance, signals: runtime.JSValue) anyerror!*runtime.Instance {
    _ = instance;
    _ = signals;
    return error.NotImplemented;
}

/// Add an abort algorithm to the signal
/// Spec: https://dom.spec.whatwg.org/#abortsignal-add
/// The callback will be invoked when the signal aborts.
/// Returns true if added, false if signal was already aborted.
pub fn addAbortAlgorithm(instance: *runtime.Instance, callback: *const fn (?*anyopaque) void, data: ?*anyopaque) !bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // If already aborted, don't add - caller should handle immediately
    if (internal.aborted) {
        return false;
    }

    try internal.abort_algorithms.append(internal.allocator, .{
        .callback = callback,
        .data = data,
    });
    return true;
}

/// Remove an abort algorithm from the signal
/// Spec: https://dom.spec.whatwg.org/#abortsignal-remove
pub fn removeAbortAlgorithm(instance: *runtime.Instance, callback: *const fn (?*anyopaque) void, data: ?*anyopaque) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    var i: usize = 0;
    while (i < internal.abort_algorithms.items.len) {
        const algo = internal.abort_algorithms.items[i];
        if (algo.callback == callback and algo.data == data) {
            _ = internal.abort_algorithms.swapRemove(i);
            return;
        }
        i += 1;
    }
}
