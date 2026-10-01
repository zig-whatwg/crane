//! Implementation for NavigateEvent interface
//!
//! HTML Standard §7.2.6.10.1 - The NavigateEvent interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-navigateevent-interface
//!
//! The navigate event the navigation API fires before a navigation. Its
//! attributes are what it was initialized to - by the constructor's
//! dictionary, or by the navigation API when it fires one ("fire a
//! push/replace/reload navigate event", "fire a traverse navigate event").
//!
//! What intercept() and scroll() record - the event's interception state,
//! its handler lists, its focus reset and scroll behaviors - is state the
//! navigation that fired the event reads and settles, so it is kept by the
//! Navigation object (dom.navigation_api): these methods perform the checks
//! that are the event's own (shared checks, canIntercept, the dispatch flag,
//! cancelable) and hand the rest to it. A constructed event is not trusted,
//! so shared checks refuse it before anything reaches the navigation API.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const clock = @import("clock");
const dom = @import("dom");
const NavigateEvent = interfaces.NavigateEvent;
const EventImpl = @import("Event.zig");
const engine = @import("engine");
const same_object = @import("same_object.zig");
const navigation_entries = @import("navigation_entries.zig");

pub const State = NavigateEvent.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SecurityError,
};

/// The objects this event's attributes name are kept alive for as long as
/// the event's wrapper is: script can hold the event after its navigation
/// has let them go. Edges, not roots (same_object.Traced).
pub const InternalState = struct {
    allocator: Allocator,
    destination_edge: same_object.Traced = .{ .slot = .{ .name = "destination" } },
    signal_edge: same_object.Traced = .{ .slot = .{ .name = "signal" } },
    form_data_edge: same_object.Traced = .{ .slot = .{ .name = "formData" } },
    source_element_edge: same_object.Traced = .{ .slot = .{ .name = "sourceElement" } },
    /// `info`: undefined when null. Still a strong hold (a value, not a
    /// platform object: traceChild cannot keep it).
    info: ?engine.Owned = null,

    fn release(self: *InternalState, event: *runtime.Instance) void {
        self.destination_edge.release(event);
        self.signal_edge.release(event);
        self.form_data_edge.release(event);
        self.source_element_edge.release(event);
        if (self.info) |value| value.release();
        self.info = null;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize NavigateEvent instance: the Event part is set by the
/// constructor.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    dom.navigation_objects.installEvents(.{ .set_navigation_type = &setNavigationType, .set_info = &setInfo });
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize NavigateEvent instance: its pins, its copied strings and
/// values, then the Event part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.release(instance);
        internal.allocator.destroy(internal);
        state.own._internal = null;
        if (state.own.downloadRequest) |*request| request.deinit(instance.ctx.allocator);
        state.own.downloadRequest = null;
    }
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps" for the Event part, then
/// each attribute from the dictionary.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: dictionaries.NavigateEventInit) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &NavigateEvent.vtable, ctx);
    errdefer deinit(instance);
    const state = instance.getState(State);
    const init_dict = eventInitDict;
    // What deinit reads, should anything below fail.
    state.base.own.type = runtime.DOMString.initEmpty();
    state.own._internal = null;
    state.own.downloadRequest = null;
    // `info` is this event's internal hold (get_info); the generated field
    // is never read.
    state.own.info = runtime.JSValue.jsUndefined;

    state.base.own.type = try @"type".clone(ctx.allocator);
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));
    state.base.own.isTrusted = false;
    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = 0; // NONE
    state.base.own.bubbles = init_dict.base.bubbles orelse false;
    state.base.own.cancelable = init_dict.base.cancelable orelse false;
    state.base.own.composed = init_dict.base.composed orelse false;
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;

    const internal = try ctx.allocator.create(InternalState);
    internal.* = .{ .allocator = ctx.allocator };
    state.own._internal = internal;

    state.own.navigationType = init_dict.navigationType orelse ._push_;
    state.own.destination = init_dict.destination;
    internal.destination_edge.hold(instance, init_dict.destination);
    state.own.canIntercept = init_dict.canIntercept orelse false;
    state.own.userInitiated = init_dict.userInitiated orelse false;
    state.own.hashChange = init_dict.hashChange orelse false;
    state.own.signal = init_dict.signal;
    internal.signal_edge.hold(instance, init_dict.signal);
    state.own.formData = init_dict.formData;
    if (init_dict.formData) |form_data| internal.form_data_edge.hold(instance, form_data);
    if (init_dict.downloadRequest) |request| state.own.downloadRequest = try request.clone(ctx.allocator);
    // `info` defaults to undefined: an absent member, and one present as
    // undefined, are the same for `any`.
    if (init_dict.info) |value| internal.info = try hold(ctx, value);
    state.own.hasUAVisualTransition = init_dict.hasUAVisualTransition orelse false;
    state.own.sourceElement = init_dict.sourceElement;
    if (init_dict.sourceElement) |element| internal.source_element_edge.hold(instance, element);

    // The inherited Event internal state and its initialized flag: without
    // them dispatchEvent throws InvalidStateError.
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);
    return instance;
}

// ============================================================================
// Attributes: "must return the values they are initialized to"
// ============================================================================

pub fn get_navigationType(instance: *runtime.Instance) anyerror!enums.NavigationType {
    return instance.getState(State).own.navigationType;
}

pub fn get_destination(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return instance.getState(State).own.destination;
}

pub fn get_canIntercept(instance: *runtime.Instance) anyerror!bool {
    return instance.getState(State).own.canIntercept;
}

pub fn get_userInitiated(instance: *runtime.Instance) anyerror!bool {
    return instance.getState(State).own.userInitiated;
}

pub fn get_hashChange(instance: *runtime.Instance) anyerror!bool {
    return instance.getState(State).own.hashChange;
}

pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return instance.getState(State).own.signal;
}

pub fn get_formData(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return instance.getState(State).own.formData;
}

/// A copy: the binding frees what a string getter returns.
pub fn get_downloadRequest(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const request = instance.getState(State).own.downloadRequest orelse return null;
    return try request.clone(instance.ctx.allocator);
}

pub fn get_info(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return runtime.JSValue.jsUndefined;
    // The event keeps `info`; the binding releases what a getter returns, so
    // it gets a hold of its own.
    if (internal.info) |value| return (try engine.retainValue(instance.ctx, value.value)).take();
    return runtime.JSValue.jsUndefined;
}

/// `value`, kept: a platform object in its relevant realm, anything else in
/// `realm`.
fn hold(realm: runtime.Context, value: runtime.JSValue) !engine.Owned {
    return engine.retainValue(if (value == .instance) value.instance.ctx else realm, value);
}

pub fn get_hasUAVisualTransition(instance: *runtime.Instance) anyerror!bool {
    return instance.getState(State).own.hasUAVisualTransition;
}

pub fn get_sourceElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return instance.getState(State).own.sourceElement;
}

// ============================================================================
// Methods
// ============================================================================

/// intercept(options): HTML 7.2.6.10.1. Steps 1-3 and 4.1 are the event's;
/// the rest records into the navigation that fired it.
pub fn call_intercept(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationInterceptOptions)) anyerror!void {
    // Step 1: "Perform shared checks given this."
    try sharedChecks(instance);
    const own = instance.getState(State).own;
    // Step 2: "If this's canIntercept attribute was initialized to false,
    // then throw a "SecurityError" DOMException."
    if (!own.canIntercept) return error.SecurityError;
    // Step 3: "If this's dispatch flag is unset, then throw an
    // "InvalidStateError" DOMException."
    if (!EventImpl.getDispatchFlag(instance)) return error.InvalidStateError;
    const opts: dictionaries.NavigationInterceptOptions = if (options.was_passed) options.value else .{};
    // Step 4.1: "If options["precommitHandler"] exists ... if this's
    // cancelable attribute is initialized to false, then throw an
    // "InvalidStateError" DOMException."
    if (opts.precommitHandler != null and !(try EventImpl.get_cancelable(instance))) return error.InvalidStateError;
    // Steps 4.2-9.
    try dom.navigation_api.intercept(instance, .{
        .precommit_handler = if (opts.precommitHandler) |h| @ptrCast(h) else null,
        .handler = if (opts.handler) |h| @ptrCast(h) else null,
        .focus_reset = if (opts.focusReset) |f| switch (f) {
            ._after_transition_ => .after_transition,
            ._manual_ => .manual,
        } else null,
        .scroll = if (opts.scroll) |s| switch (s) {
            ._after_transition_ => .after_transition,
            ._manual_ => .manual,
        } else null,
    });
}

/// scroll(): "1. Perform shared checks given this." Steps 2-3 read the
/// interception state the navigation keeps.
pub fn call_scroll(instance: *runtime.Instance) anyerror!void {
    try sharedChecks(instance);
    try dom.navigation_api.scroll(instance);
}

/// HTML "perform shared checks" for a NavigateEvent.
pub fn sharedChecks(instance: *runtime.Instance) !void {
    // Step 1: "If event's relevant global object's associated Document is
    // not fully active, then throw an "InvalidStateError" DOMException."
    if (!relevantDocumentFullyActive(instance)) return error.InvalidStateError;
    // Step 2: "If event's isTrusted attribute was initialized to false, then
    // throw a "SecurityError" DOMException."
    if (!(try EventImpl.get_isTrusted(instance))) return error.SecurityError;
    // Step 3: "If event's canceled flag is set, then throw an
    // "InvalidStateError" DOMException."
    if (try EventImpl.get_defaultPrevented(instance)) return error.InvalidStateError;
}

fn relevantDocumentFullyActive(instance: *runtime.Instance) bool {
    const record = instance.ctx.getRealm() orelse return false;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return false));
    return navigation_entries.scopeOf(window, runtime.SlabAllocator.generationOf(window)) != null;
}

// ============================================================================
// dom.navigation_objects: a precommit redirect() changes the event
// ============================================================================

fn setNavigationType(instance: *runtime.Instance, kind: dom.navigation_api.Kind) void {
    const state = instance.stateAs(State) orelse return;
    state.own.navigationType = switch (kind) {
        .push => ._push_,
        .replace => ._replace_,
        .reload => ._reload_,
        .traverse => ._traverse_,
    };
}

fn setInfo(instance: *runtime.Instance, info: runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const kept = try hold(instance.ctx, info);
    if (internal.info) |old| old.release();
    internal.info = kept;
}
