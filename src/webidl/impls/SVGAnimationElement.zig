//! Implementation for SVGAnimationElement interface (SVG Animations 2 5.2):
//! the base of <set>, <animate>, <animateMotion> and <animateTransform>.
//!
//! Each animation element owns its timing state
//! (dom.smil.document_animations.AnimationState: its SMIL timed element,
//! its target, its timeline), made with it and freed with it. Everything
//! that reads or moves that state - insertion and removal, the timing
//! attributes' change steps, the rendering step, the TimeEvents - is
//! dom.smil.document_animations', reached through the hook installed here.
//!
//! https://svgwg.org/specs/animations/#InterfaceSVGAnimationElement

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const SVGAnimationElement = interfaces.SVGAnimationElement;
const animations = dom.smil.document_animations;

pub const State = SVGAnimationElement.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = animations.AnimationState;

/// The state's two exits (dom.orphan_states): this element's deinit, and the
/// sweep at its Browser's end for an orphan no deinit reaches.
const States = dom.orphan_states.Swept(.svg_animation_element, InternalState);

/// The element's timing state, made the first time anything asks for it
/// (its insertion, a timing attribute's change, a timing method).
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    if (state.own._internal) |internal| return internal;
    const made = States.create(instance, InternalState.init(instance.ctx.allocator, instance)) catch return null;
    state.own._internal = made;
    return made;
}

/// The timing state goes with the element: off its timeline and its
/// syncbases first, then what it owns.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.detach();
    state.own._internal = null;
    States.destroy(instance);
}

/// The hooks this type owns, installed once, at process start.
pub fn installHooks() void {
    States.installSweep();
    animations.installAnimationElement(.{ .state_of = &getInternal });
    dom.mutation.registerInsertionStepsCallback(&animations.insertionSteps) catch @panic("SMIL insertion steps allocation");
    dom.mutation.registerRemovingStepsCallback(&animations.removingSteps) catch @panic("SMIL removing steps allocation");
    inline for (.{ "set", "animate", "animateMotion", "animateTransform" }) |name| {
        dom.attribute_change_steps.installForSvgElement(name, &animations.attributeChanged);
    }
}

/// Getter for targetElement: "The element which is being animated. If no
/// target element is being animated ... the value returned is null."
pub fn get_targetElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return animations.targetElement(internal);
}

/// onbegin, onend and onrepeat are the event handlers of beginEvent,
/// endEvent and repeatEvent (SVG Animations 2 5.2; SVG 2 15.8's animation
/// event attributes): their event types are not the handler names less
/// "on", so the accessors name them.
pub fn get_onbegin(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "beginEvent");
}

pub fn get_onend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "endEvent");
}

pub fn get_onrepeat(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "repeatEvent");
}

pub fn set_onbegin(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "beginEvent", value);
}

pub fn set_onend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "endEvent", value);
}

pub fn set_onrepeat(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "repeatEvent", value);
}

/// getCurrentTime(): "the current time in seconds relative to time zero
/// for the given time container".
pub fn call_getCurrentTime(instance: *runtime.Instance) anyerror!f32 {
    const internal = getInternal(instance) orelse return 0;
    return animations.currentTime(internal);
}

/// getStartTime(): the begin of the current interval; "If there is no
/// current interval, then a DOMException with code INVALID_STATE_ERR is
/// thrown."
pub fn call_getStartTime(instance: *runtime.Instance) anyerror!f32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const begin = internal.timed.interval.begin;
    if (!begin.isFinite()) return error.InvalidStateError;
    return @floatCast(begin.seconds());
}

/// getSimpleDuration(): "If the simple duration is undefined ... then an
/// exception is raised" (NOT_SUPPORTED_ERR).
pub fn call_getSimpleDuration(instance: *runtime.Instance) anyerror!f32 {
    const internal = getInternal(instance) orelse return error.NotSupportedError;
    const duration = internal.timed.simpleDuration();
    if (!duration.isFinite()) return error.NotSupportedError;
    return @floatCast(duration.seconds());
}

/// beginElement(): "equivalent to beginElementAt(0)".
pub fn call_beginElement(instance: *runtime.Instance) anyerror!void {
    return call_beginElementAt(instance, 0);
}

/// beginElementAt(offset): a begin instance time at the current time plus
/// `offset`.
pub fn call_beginElementAt(instance: *runtime.Instance, offset: f32) anyerror!void {
    const internal = getInternal(instance) orelse return;
    animations.addScriptInstanceTime(internal, .begin, offset);
}

/// endElement(): "equivalent to endElementAt(0)".
pub fn call_endElement(instance: *runtime.Instance) anyerror!void {
    return call_endElementAt(instance, 0);
}

/// endElementAt(offset): an end instance time at the current time plus
/// `offset`.
pub fn call_endElementAt(instance: *runtime.Instance, offset: f32) anyerror!void {
    const internal = getInternal(instance) orelse return;
    animations.addScriptInstanceTime(internal, .end, offset);
}
