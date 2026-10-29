//! Implementation for CSSTransition interface (CSS Transitions 2 6.1): an
//! Animation made by the style engine when a transition starts. Its model
//! is Animation's; its owning element, property and events are
//! dom.animations.css_events'. Nothing makes one from CSS yet (the style
//! engine's batch).
//!
//! Spec: https://drafts.csswg.org/css-transitions-2/#the-CSSTransition-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const animations = @import("dom").animations;
const CSSTransition = interfaces.CSSTransition;

pub const State = CSSTransition.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Getter for transitionProperty: the transitioning property's name.
pub fn get_transitionProperty(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const animation = animations.hooks.animationOf(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initInterned(animations.css_events.nameOf(animation));
}
