//! Implementation for SVGElement interface
//!
//! The members SVGElement includes are its mixins', implemented once in each
//! mixin's impl and inherited by alias (codegen/inherited_mixins.zig):
//! HTMLOrSVGOrMathMLElement (dataset, nonce, autofocus, tabIndex, focus,
//! blur; the nonce slot is the element's rare data, which Element's teardown
//! frees), ElementCSSInlineStyle (style, attributeStyleMap),
//! GlobalEventHandlers.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const SVGElement = interfaces.SVGElement;
const dom = @import("dom");

pub const State = SVGElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data. None.
pub const InternalState = struct {};

/// SVG 2 4.4.1: className reflects class through a [SameObject] animated string.
pub fn get_className(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.SVGAnimatedString.initWith(instance.ctx.allocator, instance.ctx, .{
        .reflected_element = instance,
        .reflected_attribute = "class",
    });
}

/// Getter for ownerSVGElement
pub fn get_ownerSVGElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for viewportElement
pub fn get_viewportElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}
