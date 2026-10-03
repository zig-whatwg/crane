//! Implementation for CustomEvent interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-customevent
//! WHATWG DOM Standard §2.4
//!
//! CustomEvent extends Event and adds a detail property for custom data.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const clock = @import("clock");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const CustomEvent = interfaces.CustomEvent;
const Event = interfaces.Event;
/// CustomEvent is an Event: its ancestor's state is reached through Event's
/// impl (AGENTS.md "The impls boundary", rule 1).
const EventImpl = @import("Event.zig");

pub const State = CustomEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for CustomEvent implementation. Its detail is not here:
/// the event's wrapper keeps it (`detail_slot`).
pub const InternalState = struct {
    /// The event was made by its constructor (or createEvent).
    initialized: bool = true,
};

/// Where the event keeps its detail attribute's value: an edge from its
/// wrapper (engine.traceValue), never a root. The value the constructor
/// receives belongs to the argument conversion - a string's bytes are freed
/// when the constructor returns, which is how `e.detail` once came back as
/// U+FFFD garbage - so the event keeps a value of its own; held as a root (an
/// engine.Owned), a detail that closed over its event, or one of another
/// realm, kept that realm alive for as long as the event's instance lived.
/// Blink: CustomEvent::detail_ is a TraceWrapperV8Reference.
const detail_slot: engine.TracedSlot = .{ .name = "detail" };

/// Set `event`'s detail attribute to `value` (borrowed). A platform object is
/// kept as its wrapper in its relevant realm.
fn setDetail(event: *runtime.Instance, value: runtime.JSValue) void {
    engine.traceValue(event, value, detail_slot);
}

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // CustomEvent's detail is typically a JS value that doesn't need Zig cleanup

    // Release CustomEvent's OWN internal block. The parent's deinit releases the
    // Event-level one, which on a CustomEvent instance is a different allocation -
    // so delegating alone left this one held for the life of the process.
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // An event freed before script saw it (its constructor failed) lets
        // the detail waiting for its wrapper go; a collected one's went with
        // the wrapper.
        engine.forgetTracedChild(instance, detail_slot);
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }

    // Call parent Event deinit to clean up base class resources (including state.base.own.type)
    interfaces.Event.deinit(instance);
}

/// Constructor implementation
/// Spec: https://dom.spec.whatwg.org/#dom-customevent-customevent
///
/// The CustomEvent(type, eventInitDict) constructor steps are:
/// 1. Run the Event constructor steps (inherited)
/// 2. Set this's detail attribute to eventInitDict["detail"]
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.CustomEventInit)) !*runtime.Instance {
    // Create instance
    const instance = try init(ctx.allocator, State, &CustomEvent.vtable, ctx);
    errdefer deinit(instance);

    // Get state
    const state = instance.getState(State);

    // Create internal state for CustomEvent
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState{};
    state.own._internal = internal;
    // CustomEventInit's `any detail = null`: the dictionary member's default.
    const detail_value = if (eventInitDict.was_passed and eventInitDict.value.detail != null)
        eventInitDict.value.detail.?
    else
        runtime.JSValue.jsNull;
    setDetail(instance, detail_value);

    state.base.own.type = try @"type".clone(ctx.allocator);

    const base_init = if (eventInitDict.wasPassed()) eventInitDict.value.base else dictionaries.EventInit{};
    state.base.own.bubbles = base_init.bubbles orelse false;
    state.base.own.cancelable = base_init.cancelable orelse false;
    state.base.own.composed = base_init.composed orelse false;

    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = interfaces.Event.get_NONE();
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true; // !canceled_flag
    state.base.own.defaultPrevented = false;
    state.base.own.isTrusted = false;
    state.base.own.timeStamp = @as(f64, @floatFromInt(clock.monotonicMillis()));

    // Create the INHERITED Event internal state and set the initialized flag.
    // Without it dispatchEvent throws InvalidStateError, so the event can be
    // constructed but never dispatched. Same thing MouseEvent does by hand.
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);

    return instance;
}

/// Getter for detail
/// Spec: https://dom.spec.whatwg.org/#dom-customevent-detail
/// Returns the value it was initialized with.
pub fn get_detail(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // The event keeps its detail; the binding gets a hold of its own.
    _ = getInternal(instance) orelse return runtime.JSValue.jsNull;
    const detail = engine.tracedValue(instance, detail_slot) orelse return runtime.JSValue.jsNull;
    return detail.take();
}

/// Operation: initCustomEvent (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-customevent-initcustomevent
///
/// The initCustomEvent(type, bubbles, cancelable, detail) method steps are:
/// 1. If this's dispatch flag is set, then return.
/// 2. Initialize this with type, bubbles, and cancelable.
/// 3. Set this's detail attribute to detail.
pub fn call_initCustomEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), detail: webidl.Opt(runtime.JSValue)) anyerror!void {
    // Step 1: If this's dispatch flag is set, then return.
    if (EventImpl.getDispatchFlag(instance)) return;

    // Step 2: Initialize this with type, bubbles, and cancelable - Event's
    // own initEvent steps (their step 1 is this one, and holds).
    try EventImpl.call_initEvent(instance, @"type", bubbles, cancelable);

    // Step 3: Set this's detail attribute to detail (`optional any detail =
    // null`).
    _ = getInternal(instance) orelse return;
    setDetail(instance, if (detail.was_passed) detail.value else runtime.JSValue.jsNull);
}
