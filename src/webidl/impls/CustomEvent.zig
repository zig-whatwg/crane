//! Implementation for CustomEvent interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-customevent
//! WHATWG DOM Standard §2.4
//!
//! CustomEvent extends Event and adds a detail property for custom data.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CustomEvent = interfaces.CustomEvent;
const Event = interfaces.Event;
const EventImpl = @import("Event.zig");

pub const State = CustomEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for CustomEvent implementation
/// Contains the detail property which is any JavaScript value.
pub const InternalState = struct {
    /// The detail property - any JavaScript value passed to the constructor
    /// Now stored as engine-agnostic JSValue
    detail: runtime.JSValue = runtime.JSValue.jsUndefined,
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Constructor implementation
/// Spec: https://dom.spec.whatwg.org/#dom-customevent-customevent
///
/// The CustomEvent(type, eventInitDict) constructor steps are:
/// 1. Run the Event constructor steps (inherited)
/// 2. Set this's detail attribute to eventInitDict["detail"]
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.CustomEventInit)) !*runtime.Instance {
    // Create instance
    _ = @"type"; // Event type handled by parent Event
    const instance = try init(allocator, State, &CustomEvent.vtable, ctx);
    errdefer deinit(instance);

    // Get state
    const state = instance.getState(State);

    // Create internal state for CustomEvent
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    const detail_value = if (eventInitDict.was_passed and eventInitDict.value.detail != null)
        eventInitDict.value.detail.?
    else
        runtime.JSValue.jsUndefined;
    internal.* = InternalState{
        .detail = detail_value,
    };
    state.own._internal = internal;

    // Store detail in state (for direct access)
    state.own.detail = detail_value;

    // Note: CustomEvent inherits from Event via prototype chain
    // The base Event state is accessed through state.base (which is *Event)
    // However, since BaseType is *Event (pointer), we don't have embedded Event state
    // The inheritance is handled at the V8/JS level through prototype chain

    // Note: @"type" and EventInit fields would be stored in parent Event state
    // but since Event is accessed via prototype chain, that's handled at V8 level

    return instance;
}

/// Getter for detail
/// Spec: https://dom.spec.whatwg.org/#dom-customevent-detail
/// Returns the value it was initialized with.
pub fn get_detail(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    return state.own.detail;
}

/// Operation: initCustomEvent (legacy)
/// Spec: https://dom.spec.whatwg.org/#dom-customevent-initcustomevent
///
/// The initCustomEvent(type, bubbles, cancelable, detail) method steps are:
/// 1. If this's dispatch flag is set, then return.
/// 2. Initialize this with type, bubbles, and cancelable.
/// 3. Set this's detail attribute to detail.
pub fn call_initCustomEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), detail: webidl.Opt(runtime.JSValue)) anyerror!void {
    // Step 1: Check dispatch flag
    // Note: Would check via Event's dispatch flag, but we don't have direct access
    // For now, proceed with initialization

    // Step 2: Initialize event (would call parent's initEvent logic)
    // Since Event state is accessed via prototype chain in JS, we can't directly call it here
    // The JS runtime handles inheritance
    _ = @"type";
    _ = bubbles;
    _ = cancelable;

    // Step 3: Set detail
    const state = instance.getState(State);
    if (detail.was_passed) {
        state.own.detail = detail.value;
        if (getInternal(instance)) |internal| {
            internal.detail = detail.value;
        }
    }
}
