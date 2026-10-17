//! Implementation for the HTMLOrSVGOrMathMLElement mixin (formerly
//! HTMLOrSVGElement; HTML now includes it in MathMLElement too).
//!
//! The mixin is not on codegen/inherited_mixins.zig yet, so each includer's
//! generated interface binds the includer's own impl: HTMLElement,
//! SVGElement and MathMLElement answer dataset, nonce, tabIndex, focus() and
//! blur() (focus and blur through src/html/focus.zig). Nothing called this
//! impl's copies of focus() and blur(), so they did not move with the
//! rename. Moving the members here - the nonce slot first, into a src/dom
//! store - is the queued "HTMLOrSVGOrMathMLElement inherited" follow-up.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLOrSVGOrMathMLElement = interfaces.HTMLOrSVGOrMathMLElement;

pub const State = HTMLOrSVGOrMathMLElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};
