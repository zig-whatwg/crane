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
const v8 = @import("v8");
const AbortSignal = interfaces.AbortSignal;
const EventTargetImpl = @import("EventTarget.zig");
const streams_js = @import("streams_js.zig");

pub const State = AbortSignal.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
    AbortError,
};

/// A signal held weakly - as a signal's source and dependent signals are,
/// "weak sets" in DOM - by (address, slab generation): a collected signal's
/// slot can be reissued, and then the address means someone else.
const SignalRef = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) SignalRef {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    /// The signal, if it is still the one this refers to.
    fn get(self: SignalRef) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

/// Internal state for AbortSignal
///
/// Spec: https://dom.spec.whatwg.org/#abortsignal
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Whether the signal is aborted: "abort reason is not undefined". Kept
    /// as its own flag because a reason can itself be the value undefined
    /// only in a signal made before any reason existed.
    aborted: bool = false,

    /// Abort reason: an owned Global<Value>, or null for undefined.
    reason: ?*v8.ffi.Value = null,

    /// DOM § 3.3 "abort algorithms": run, in order, when the signal is aborted.
    abort_algorithms: std.ArrayListUnmanaged(AbortAlgorithm) = .empty,

    /// "dependent", "source signals" and "dependent signals" (DOM § 3.3).
    dependent: bool = false,
    source_signals: std.ArrayListUnmanaged(SignalRef) = .empty,
    dependent_signals: std.ArrayListUnmanaged(SignalRef) = .empty,

    /// AbortSignal.timeout()'s pending timer, cancelled if the signal goes
    /// first.
    timeout: ?*TimeoutTask = null,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        if (self.reason) |r| v8.ffi.v8_Global_Dispose(r);
        // A signal that dies unaborted never runs these; their owners gave
        // them to the signal, so it hands each back to be freed.
        for (self.abort_algorithms.items) |algorithm| {
            if (algorithm.drop) |drop| drop(algorithm.ctx);
        }
        self.abort_algorithms.deinit(allocator);
        self.source_signals.deinit(allocator);
        self.dependent_signals.deinit(allocator);
        if (self.timeout) |task| task.cancel();
        allocator.destroy(self);
    }
};

/// An abort algorithm (DOM § 3.3): `run(ctx)` once, when the signal aborts.
/// Identified by `ctx` for removal.
pub const AbortAlgorithm = abort_algorithms.Algorithm;

/// The hook other specifications reach these through (no IDL member adds an
/// abort algorithm, so they cannot go through the interface).
const abort_algorithms = @import("dom").abort_algorithms;

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// DOM § 3.3 "add an algorithm to an AbortSignal": does nothing when the
/// signal is already aborted.
fn addAlgorithm(instance: *runtime.Instance, algorithm: AbortAlgorithm) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    // Step 1: If signal is aborted, then return.
    if (internal.aborted) return;
    // Step 2: Append algorithm to signal's abort algorithms.
    try internal.abort_algorithms.append(internal.allocator, algorithm);
}

/// DOM § 3.3 "remove an algorithm from an AbortSignal".
fn removeAlgorithm(instance: *runtime.Instance, ctx: *anyopaque) void {
    const internal = getInternal(instance) orelse return;
    var i: usize = 0;
    while (i < internal.abort_algorithms.items.len) {
        if (internal.abort_algorithms.items[i].ctx == ctx) {
            _ = internal.abort_algorithms.orderedRemove(i);
        } else i += 1;
    }
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // An AbortSignal is an EventTarget: `abort` is fired at it and heard.
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);

    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;

    // Nobody can hold a signal to add an algorithm to before one exists.
    abort_algorithms.install(.{ .add = addAlgorithm, .remove = removeAlgorithm, .create_dependent = createDependentAbortSignal });

    return instance;
}

/// A new AbortSignal in `ctx`'s realm.
fn newSignal(ctx: runtime.Context) !*runtime.Instance {
    return init(ctx.allocator, State, &AbortSignal.vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    EventTargetImpl.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for aborted
///
/// Spec: "return true if this is aborted; otherwise false."
pub fn get_aborted(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidState;
    return internal.aborted;
}

/// Getter for reason
///
/// Spec: "return this's abort reason." Borrowed by the caller.
pub fn get_reason(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const reason = internal.reason orelse return runtime.JSValue.jsUndefined;
    return streams_js.toReturn(reason);
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "abort");
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "abort", value);
}

/// Static operation: any(signals)
///
/// Spec: "return the result of creating a dependent abort signal from
/// signals using AbortSignal and the current realm."
///
/// Deviation: `sequence<AbortSignal>` arrives unconverted, and only an Array
/// is accepted, where WebIDL would take any iterable.
pub fn call_static_any(instance: *runtime.Instance, signals: runtime.JSValue) anyerror!*runtime.Instance {
    const allocator = instance.ctx.allocator;
    const realm = try streams_js.Realm.of(instance);
    const handle: *v8.ffi.Value = switch (signals) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        else => return error.TypeError,
    };
    if (!v8.ffi.v8_Value_IsArray(handle)) return error.TypeError;
    const array: *v8.ffi.Array = @ptrCast(handle);

    var list: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer list.deinit(allocator);
    const length = v8.ffi.v8_Array_Length(array);
    var i: u32 = 0;
    while (i < length) : (i += 1) {
        const element = v8.ffi.v8_Array_Get(realm.context, array, i) orelse return error.TypeError;
        defer v8.ffi.v8_Global_Dispose(element);
        try list.append(allocator, signalOf(element) orelse return error.TypeError);
    }
    return createDependentAbortSignal(instance.ctx, list.items);
}

/// The AbortSignal `value` wraps, or null when it is not one.
fn signalOf(value: *v8.ffi.Value) ?*runtime.Instance {
    if (!v8.ffi.v8_Value_IsObject(value)) return null;
    const object: *v8.ffi.Object = @ptrCast(value);
    if (v8.ffi.v8_Object_InternalFieldCount(object) < 1) return null;
    const pointer = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(object, 0) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(pointer));
    if (instance.stateAs(State) == null) return null;
    return instance;
}

/// Static operation: abort(reason)
///
/// Spec: "1. Let signal be a new AbortSignal object. 2. Set signal's abort
/// reason to reason if it is given; otherwise to a new "AbortError"
/// DOMException. 3. Return signal."
pub fn call_static_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    const signal = try newSignal(instance.ctx);
    const internal = getInternal(signal).?;
    internal.reason = try reasonOrDefault(signal, if (reason.was_passed) reason.value else runtime.JSValue.jsUndefined, "AbortError", "signal is aborted without reason");
    internal.aborted = true;
    return signal;
}

/// Static operation: timeout(milliseconds)
///
/// Spec: "1. Let signal be a new AbortSignal object. 2. Let global be
/// signal's relevant global object. 3. Run steps after a timeout given
/// global, "AbortSignal-timeout", milliseconds, and the following step: queue
/// a global task on the timer task source given global to signal abort given
/// signal and a new "TimeoutError" DOMException. 4. Return signal."
///
/// Deviation: nothing keeps an unreferenced signal alive while its timer is
/// pending; the timer then finds it gone and does nothing.
pub fn call_static_timeout(instance: *runtime.Instance, milliseconds: u64) anyerror!*runtime.Instance {
    const signal = try newSignal(instance.ctx);
    const timer = signal.ctx.timer orelse return signal;
    const internal = getInternal(signal).?;
    const task = try internal.allocator.create(TimeoutTask);
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return signal;
    task.* = .{ .signal = SignalRef.of(signal), .allocator = internal.allocator, .timer = timer, .isolate = isolate };
    task.id = timer.setTimeout(milliseconds, &TimeoutTask.fire, task);
    if (task.id == 0) {
        internal.allocator.destroy(task);
        return signal;
    }
    internal.timeout = task;
    return signal;
}

const TimeoutTask = struct {
    signal: SignalRef,
    allocator: std.mem.Allocator,
    timer: runtime.TimerInterface,
    /// The signal's isolate. A worker's is not the page's, and the timer
    /// may fire from the page's event loop.
    isolate: *v8.ffi.Isolate,
    id: runtime.TimerId = 0,

    fn fire(data: ?*anyopaque) void {
        const task: *TimeoutTask = @ptrCast(@alignCast(data orelse return));
        defer task.allocator.destroy(task);
        const signal = task.signal.get() orelse return;
        const internal = getInternal(signal) orelse return;
        internal.timeout = null;
        // A task, entered from the event loop rather than from script - and
        // possibly from another isolate's loop.
        const entered = v8.ffi.v8_Isolate_GetCurrent() != task.isolate;
        if (entered) v8.ffi.v8_Isolate_Enter(task.isolate);
        defer if (entered) v8.ffi.v8_Isolate_Exit(task.isolate);
        const scope = v8.JsScope.init(signal.ctx) orelse return;
        defer scope.deinit();
        const reason = newDOMException(signal, "TimeoutError", "signal timed out") catch return;
        defer v8.ffi.v8_Global_Dispose(reason);
        signalAbortWith(signal, reason);
        // In a worker, the task's end is the worker's to run.
        @import("html").worker_v8_context.finishTaskIn(task.isolate);
    }

    /// The signal is going: its timer must not fire into it.
    fn cancel(self: *TimeoutTask) void {
        _ = self.timer.clearTimeout(self.id);
        self.allocator.destroy(self);
    }
};

/// Operation: throwIfAborted
///
/// Spec: "If this is aborted, then throw this's abort reason."
pub fn call_throwIfAborted(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    if (!internal.aborted) return;
    const realm = try streams_js.Realm.of(instance);
    const reason = internal.reason orelse try realm.undefinedValue();
    defer if (internal.reason == null) streams_js.dispose(reason);
    return realm.throwValue(reason);
}

// ============================================================================
// DOM § 3.3 algorithms other types reach (AbortController, Fetch, Streams)
// ============================================================================

/// A new "`name`" DOMException of `signal`'s realm. Owned.
fn newDOMException(signal: *runtime.Instance, name: []const u8, message: []const u8) !*v8.ffi.Value {
    const realm = try streams_js.Realm.of(signal);
    return v8.conversions.newDOMExceptionFromContext(realm.isolate, realm.context, name, message) orelse error.V8Failure;
}

/// `reason` as an owned Global, or a new `name` DOMException when it is
/// undefined - an optional `any` argument not given.
fn reasonOrDefault(signal: *runtime.Instance, reason: runtime.JSValue, name: []const u8, message: []const u8) !*v8.ffi.Value {
    if (!reason.isUndefined()) {
        const realm = try streams_js.Realm.of(signal);
        return realm.fromRuntime(reason);
    }
    return newDOMException(signal, name, message);
}

/// DOM § 3.3 "signal abort", given an optional reason (undefined: not
/// given). AbortController.abort() and the Streams AbortSteps reach it. The
/// reason is borrowed.
pub fn signalAbort(instance: *runtime.Instance, reason: runtime.JSValue) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    // Step 1: If signal is aborted, then return.
    if (internal.aborted) return;
    // Step 2: Set signal's abort reason to reason if it is given; otherwise
    // to a new "AbortError" DOMException.
    const owned = reasonOrDefault(instance, reason, "AbortError", "signal is aborted without reason") catch return error.OutOfMemory;
    defer v8.ffi.v8_Global_Dispose(owned);
    signalAbortWith(instance, owned);
}

/// "Signal abort" steps 2-6 with the reason decided. `reason` is borrowed;
/// every signal that takes it takes its own handle.
fn signalAbortWith(signal: *runtime.Instance, reason: *v8.ffi.Value) void {
    const internal = getInternal(signal) orelse return;
    if (internal.aborted) return;
    setReason(internal, reason);

    // Step 3: Let dependentSignalsToAbort be a new list.
    var to_abort: std.ArrayListUnmanaged(SignalRef) = .empty;
    defer to_abort.deinit(internal.allocator);
    // Step 4: For each dependentSignal of signal's dependent signals: if it
    // is not aborted, set its abort reason to signal's abort reason and
    // append it.
    for (internal.dependent_signals.items) |ref| {
        const dependent = ref.get() orelse continue;
        const dependent_internal = getInternal(dependent) orelse continue;
        if (dependent_internal.aborted) continue;
        setReason(dependent_internal, reason);
        to_abort.append(internal.allocator, ref) catch continue;
    }

    // Step 5: Run the abort steps for signal.
    runAbortSteps(signal);
    // Step 6: For each dependentSignal of dependentSignalsToAbort, run the
    // abort steps for dependentSignal.
    for (to_abort.items) |ref| {
        const dependent = ref.get() orelse continue;
        runAbortSteps(dependent);
    }
}

fn setReason(internal: *InternalState, reason: *v8.ffi.Value) void {
    internal.aborted = true;
    if (internal.reason) |old| v8.ffi.v8_Global_Dispose(old);
    internal.reason = v8.ffi.v8_Global_Clone(reason);
}

/// DOM § 3.3 "run the abort steps" for `signal`.
fn runAbortSteps(signal: *runtime.Instance) void {
    const internal = getInternal(signal) orelse return;
    // Steps 1-2: For each algorithm of signal's abort algorithms, run it;
    // then empty them. Taken first, so an algorithm that adds or removes one
    // does not disturb this walk.
    var algorithms = internal.abort_algorithms;
    internal.abort_algorithms = .empty;
    defer algorithms.deinit(internal.allocator);
    for (algorithms.items) |algorithm| algorithm.run(algorithm.ctx);

    // Step 3: Fire an event named abort at signal.
    const event = interfaces.Event.call_constructor(
        signal.ctx,
        runtime.DOMString.initInterned("abort"),
        webidl.Opt(dictionaries.EventInit).notPassed(),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    // "Signal abort" step 5 fires an event: trusted (DOM 2.10).
    _ = EventTargetImpl.dispatchTrusted(signal, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// DOM § 3.3 "create a dependent abort signal" from `signals`, using
/// AbortSignal, in `ctx`'s realm.
pub fn createDependentAbortSignal(ctx: runtime.Context, signals: []const *runtime.Instance) !*runtime.Instance {
    // Step 1: Let resultSignal be a new object implementing signalInterface.
    const result = try newSignal(ctx);
    const result_internal = getInternal(result).?;
    const allocator = result_internal.allocator;

    // Step 2: For each signal of signals: if signal is aborted, set
    // resultSignal's abort reason to signal's abort reason and return it.
    for (signals) |signal| {
        const internal = getInternal(signal) orelse continue;
        if (!internal.aborted) continue;
        result_internal.aborted = true;
        if (internal.reason) |r| result_internal.reason = v8.ffi.v8_Global_Clone(r);
        return result;
    }

    // Step 3: Set resultSignal's dependent to true.
    result_internal.dependent = true;

    // Step 4: For each signal of signals:
    for (signals) |signal| {
        const internal = getInternal(signal) orelse continue;
        if (!internal.dependent) {
            // Step 4.1: If signal's dependent is false, append signal to
            // resultSignal's source signals and resultSignal to signal's
            // dependent signals.
            try link(allocator, result_internal, result, internal, signal);
        } else {
            // Step 4.2: Otherwise, for each sourceSignal of signal's source
            // signals, do the same with sourceSignal. (A source is never
            // aborted - it would have aborted signal - nor dependent.)
            for (internal.source_signals.items) |ref| {
                const source = ref.get() orelse continue;
                const source_internal = getInternal(source) orelse continue;
                try link(allocator, result_internal, result, source_internal, source);
            }
        }
    }
    // Step 5: Return resultSignal.
    return result;
}

/// Append `source` to `result`'s source signals and `result` to `source`'s
/// dependent signals - sets, so each at most once.
fn link(allocator: std.mem.Allocator, result_internal: *InternalState, result: *runtime.Instance, source_internal: *InternalState, source: *runtime.Instance) !void {
    for (result_internal.source_signals.items) |ref| {
        if (ref.get() == source) return;
    }
    try result_internal.source_signals.append(allocator, SignalRef.of(source));
    try source_internal.dependent_signals.append(source_internal.allocator, SignalRef.of(result));
}
