//! Implementation for TransitionEvent interface
//!
//! Spec: https://drafts.csswg.org/css-transitions-1/#interface-transitionevent
//!
//! ```idl
//! [Exposed=Window]
//! interface TransitionEvent : Event {
//!   constructor(CSSOMString type, optional TransitionEventInit transitionEventInitDict = {});
//!   readonly attribute CSSOMString propertyName;
//!   readonly attribute double elapsedTime;
//!   readonly attribute CSSOMString pseudoElement;
//! };
//! ```
//!
//! Nothing in Crane fires one yet - no style engine runs CSS transitions - so an
//! event made by script is all there is; "invoke" step 9 renames a trusted
//! one for its legacy webkit listeners (EventTarget).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const event_construction = @import("dom").event_construction;
const TransitionEvent = interfaces.TransitionEvent;

pub const State = TransitionEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Nothing beyond the attributes, which the generated State holds.
pub const InternalState = struct {};

/// Initialize instance: the Event part (its internal state, the constructing
/// steps it installs), then this interface's attributes, empty.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.Event.initWithState(allocator, StateType, vtable, ctx);
    const state = instance.getState(StateType);
    state.own.propertyName = runtime.DOMString.initEmpty();
    state.own.elapsedTime = 0;
    state.own.animation = null;
    state.own.pseudoElement = runtime.DOMString.initEmpty();
    return instance;
}

/// Deinitialize instance: its own strings, then the Event part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    // The animation member's edge (safe in teardown: a collected event's
    // went with its wrapper).
    if (state.own.animation != null) @import("engine").forgetTracedChild(instance, animation_slot);
    state.own.animation = null;
    state.own.propertyName.deinit(instance.ctx.allocator);
    state.own.pseudoElement.deinit(instance.ctx.allocator);
    state.own.propertyName = runtime.DOMString.initEmpty();
    state.own.pseudoElement = runtime.DOMString.initEmpty();
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps" with the dictionary's
/// EventInit part, then each TransitionEventInit member initializing the attribute
/// of its name (propertyName and pseudoElement "", elapsedTime 0 by default).
pub fn call_constructor(ctx: runtime.Context, @"type": typedefs.CSSOMString, transitionEventInitDict: webidl.Opt(dictionaries.TransitionEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &TransitionEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.TransitionEventInit = if (transitionEventInitDict.was_passed) transitionEventInitDict.value else .{ .base = .{} };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base));
    const state = instance.getState(State);
    // Copied: the binding frees the dictionary's strings when the
    // constructor returns.
    if (dict.propertyName) |value| state.own.propertyName = try value.clone(ctx.allocator);
    state.own.elapsedTime = dict.elapsedTime orelse 0;
    if (dict.pseudoElement) |value| state.own.pseudoElement = try value.clone(ctx.allocator);
    // css-animations-2 / css-transitions-2: the animation member, kept by a
    // traced edge for as long as the event (only a CSSTransition converts here).
    if (dict.animation) |animation| {
        @import("engine").traceChild(instance, animation, animation_slot);
        state.own.animation = animation;
    }
    return instance;
}

/// Getter for propertyName. A view of the event's own copy.
pub fn get_propertyName(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return runtime.DOMString.initInterned(instance.getState(State).own.propertyName.asSlice());
}

/// Getter for elapsedTime
pub fn get_elapsedTime(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.elapsedTime;
}

/// Getter for pseudoElement. A view of the event's own copy.
pub fn get_pseudoElement(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return runtime.DOMString.initInterned(instance.getState(State).own.pseudoElement.asSlice());
}

/// Getter for animation (css-animations-2 / css-transitions-2): the
/// CSSTransition the event was fired for, or the init dictionary's animation
/// member; null for neither.
pub fn get_animation(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return instance.getState(State).own.animation;
}

const animation_slot: @import("engine").TracedSlot = .{ .name = "TransitionEvent:animation" };
