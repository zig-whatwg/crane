//! Implementation for AnimationEvent interface
//!
//! Spec: https://drafts.csswg.org/css-animations-1/#interface-animationevent
//!
//! ```idl
//! [Exposed=Window]
//! interface AnimationEvent : Event {
//!   constructor(CSSOMString type, optional AnimationEventInit animationEventInitDict = {});
//!   readonly attribute CSSOMString animationName;
//!   readonly attribute double elapsedTime;
//!   readonly attribute CSSOMString pseudoElement;
//! };
//! ```
//!
//! dom.animations.css_events fires one for a CSSAnimation (the style engine
//! does not make CSS animations yet); "invoke" step 9 renames a trusted one
//! for its legacy webkit listeners (EventTarget).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const event_construction = @import("dom").event_construction;
const AnimationEvent = interfaces.AnimationEvent;

pub const State = AnimationEvent.State;

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
    state.own.animationName = runtime.DOMString.initEmpty();
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
    state.own.animationName.deinit(instance.ctx.allocator);
    state.own.pseudoElement.deinit(instance.ctx.allocator);
    state.own.animationName = runtime.DOMString.initEmpty();
    state.own.pseudoElement = runtime.DOMString.initEmpty();
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps" with the dictionary's
/// EventInit part, then each AnimationEventInit member initializing the attribute
/// of its name (animationName and pseudoElement "", elapsedTime 0 by default).
pub fn call_constructor(ctx: runtime.Context, @"type": typedefs.CSSOMString, animationEventInitDict: webidl.Opt(dictionaries.AnimationEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &AnimationEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.AnimationEventInit = if (animationEventInitDict.was_passed) animationEventInitDict.value else .{ .base = .{} };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base));
    const state = instance.getState(State);
    // Copied: the binding frees the dictionary's strings when the
    // constructor returns.
    if (dict.animationName) |value| state.own.animationName = try value.clone(ctx.allocator);
    state.own.elapsedTime = dict.elapsedTime orelse 0;
    if (dict.pseudoElement) |value| state.own.pseudoElement = try value.clone(ctx.allocator);
    // css-animations-2 / css-transitions-2: the animation member, kept by a
    // traced edge for as long as the event (only a CSSAnimation converts here).
    if (dict.animation) |animation| {
        @import("engine").traceChild(instance, animation, animation_slot);
        state.own.animation = animation;
    }
    return instance;
}

/// Getter for animationName. A view of the event's own copy.
pub fn get_animationName(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return runtime.DOMString.initInterned(instance.getState(State).own.animationName.asSlice());
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
/// CSSAnimation the event was fired for, or the init dictionary's animation
/// member; null for neither.
pub fn get_animation(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return instance.getState(State).own.animation;
}

const animation_slot: @import("engine").TracedSlot = .{ .name = "AnimationEvent:animation" };
