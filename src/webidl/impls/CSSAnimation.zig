//! Implementation for CSSAnimation interface (CSS Animations 2 6.1): an
//! Animation made by the style engine from animation-name. Its model is
//! Animation's; its owning element, name and events are
//! dom.animations.css_events'. Nothing makes one from CSS yet (the style
//! engine's batch).
//!
//! Spec: https://drafts.csswg.org/css-animations-2/#the-CSSAnimation-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const animations = @import("dom").animations;
const CSSAnimation = interfaces.CSSAnimation;

pub const State = CSSAnimation.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Getter for animationName: the animation-name value that made it.
pub fn get_animationName(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const animation = animations.hooks.animationOf(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initInterned(animations.css_events.nameOf(animation));
}
