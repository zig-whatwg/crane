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
const performance_timeline = @import("dom").performance_timeline;
const event_construction = @import("dom").event_construction;
const CustomEvent = interfaces.CustomEvent;
const Event = interfaces.Event;
/// CustomEvent is an Event: its ancestor's state is reached through Event's
/// impl (AGENTS.md "The impls boundary", rule 1).
pub const State = CustomEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// CustomEvent keeps no state of its own: its detail is the event's
/// wrapper's (`detail_slot`), and everything else is Event's. With no field
/// the generated State keeps no pointer for it (runtime.FlattenedState's
/// `empty` kind) and no block is made: until lane ev1 a CustomEvent paid an
/// 8-byte pointer and a 16-byte block of its own for one flag nothing read.
pub const InternalState = struct {};

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
    // An event freed before script saw it (its constructor failed) lets
    // the detail waiting for its wrapper go; a collected one's went with
    // the wrapper.
    if (instance.stateAs(State) != null) engine.forgetTracedChild(instance, detail_slot);

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

    // CustomEventInit's `any detail = null`: the dictionary member's default.
    const detail_value = if (eventInitDict.was_passed and eventInitDict.value.detail != null)
        eventInitDict.value.detail.?
    else
        runtime.JSValue.jsNull;
    setDetail(instance, detail_value);

    state.base.own.type = try event_construction.ownedType(ctx.allocator, @"type");

    const base_init = if (eventInitDict.wasPassed()) eventInitDict.value.base else dictionaries.EventInit{};
    state.base.own.bubbles = base_init.bubbles orelse false;
    state.base.own.cancelable = base_init.cancelable orelse false;
    state.base.own.composed = base_init.composed orelse false;

    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true; // !canceled_flag
    state.base.own.defaultPrevented = false;
    // DOM inner event creation step 3: relative to the relevant global.
    state.base.own.timeStamp = performance_timeline.now(instance.ctx) orelse 0;

    // Create the INHERITED Event internal state and set the initialized flag.
    // Without it dispatchEvent throws InvalidStateError, so the event can be
    // constructed but never dispatched. Same thing MouseEvent does by hand.
    try webidl.utils.initEventBase(&state.base.own, runtime.arenaOf(instance), ctx.allocator);

    return instance;
}

/// Getter for detail
/// Spec: https://dom.spec.whatwg.org/#dom-customevent-detail
/// Returns the value it was initialized with.
pub fn get_detail(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // The event keeps its detail; the binding gets a hold of its own.
    _ = instance.stateAs(State) orelse return runtime.JSValue.jsNull;
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
    if (event_construction.dispatchFlag(instance)) return;

    // Step 2: Initialize this with type, bubbles, and cancelable - Event's
    // own initEvent steps (their step 1 is this one, and holds).
    try interfaces.Event.call_initEvent(instance, @"type", bubbles, cancelable);

    // Step 3: Set this's detail attribute to detail (`optional any detail =
    // null`).
    _ = instance.stateAs(State) orelse return;
    setDetail(instance, if (detail.was_passed) detail.value else runtime.JSValue.jsNull);
}
