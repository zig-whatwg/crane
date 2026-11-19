//! Implementation for CSSStyleProperties interface (CSSOM 6.6.2)
//!
//! What getComputedStyle() and element.style return: a CSSStyleDeclaration
//! with the CSS property attributes. Its declaration block and every member
//! are CSSStyleDeclaration's (the construction chain makes its state, and
//! the inherited members run its impl); this level adds `cssFloat` and
//! answers the camel-cased and dashed attributes through the same named
//! handlers, reached through the generated interface.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssstyleproperties-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const CSSStyleProperties = interfaces.CSSStyleProperties;

pub const State = CSSStyleProperties.State;

pub const ImplError = error{
    NotImplemented,
};

/// Nothing of its own: the state is CSSStyleDeclaration's.
pub const InternalState = struct {};

/// cssFloat getter: "return the result of invoking getPropertyValue() with
/// float as argument."
pub fn get_cssFloat(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("float"));
}

/// cssFloat setter: "invoke setProperty() with float as first argument, the
/// given value as second argument, and the empty string as third argument.
/// Any exceptions thrown must be re-thrown."
pub fn set_cssFloat(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("float"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.DOMString {
    return interfaces.CSSStyleDeclaration.call_namedItem(instance, name);
}

pub fn call_setNamedItem(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setNamedItem(instance, name, value);
}

pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    return interfaces.CSSStyleDeclaration.getSupportedPropertyNames(instance, allocator);
}
