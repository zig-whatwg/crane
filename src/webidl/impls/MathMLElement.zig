//! Implementation for MathMLElement interface (MathML Core 2.2.3).
//!
//! Every member MathMLElement has is a mixin's, implemented once in that
//! mixin's impl and inherited by alias (codegen/inherited_mixins.zig):
//! GlobalEventHandlers, HTMLOrSVGOrMathMLElement (dataset, nonce, autofocus,
//! tabIndex, focus, blur) and ElementCSSInlineStyle (style,
//! attributeStyleMap).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const MathMLElement = interfaces.MathMLElement;

pub const State = MathMLElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data. None.
pub const InternalState = struct {};

// No state of our own: use the generated Element/Node construction and
// destruction chain, including when MathMLAnchorElement derives from us.
