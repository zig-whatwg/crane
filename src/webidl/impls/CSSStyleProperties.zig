//! Implementation for CSSStyleProperties interface (CSSOM 6.6.2)
//!
//! What getComputedStyle() and element.style return: a CSSStyleDeclaration
//! with the CSS property attributes. Its declaration block and every member
//! are CSSStyleDeclaration's (the construction chain makes its state, and
//! the inherited members run its impl); this level adds `cssFloat` and the
//! camel-cased, webkit-cased and dashed attributes, which the binding
//! defines as accessors on the prototype (`css_property_attributes`): no
//! named property of the object itself, as in Firefox and Safari
//! (css/cssom/cssstyledeclaration-properties.html: Firefox 160 1/1, Safari
//! 27.2 1/1, Chrome 157 0/1 - Blink's named interceptor - at wpt.fyi runs
//! 4877168468033536, 6479119966273536, 4786307730243584).
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssstyleproperties-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const CSSStyleProperties = interfaces.CSSStyleProperties;
const css_attributes = @import("dom").style.css_attributes;

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

/// CSSOM 6.6.2: the CSS property attributes - each supported CSS
/// property's camel-cased, webkit-cased and dashed attribute - by name, in
/// the order the binding defines them on the prototype (one accessor each;
/// its index reaches the entry). dom.style.css_attributes holds the table.
pub const css_property_attributes: [css_attributes.attributes.len][:0]const u8 = blk: {
    @setEvalBranchQuota(100_000);
    var names: [css_attributes.attributes.len][:0]const u8 = undefined;
    for (css_attributes.attributes, 0..) |attribute, i| names[i] = attribute.name;
    break :blk names;
};

/// The camel-cased, webkit-cased or dashed attribute's getter: "return the
/// result of invoking getPropertyValue() with the argument being the result
/// of running the IDL attribute to CSS property algorithm" for it (the
/// dashed attribute's argument is the attribute itself).
pub fn getCssPropertyAttribute(instance: *runtime.Instance, index: usize) anyerror!runtime.DOMString {
    if (index >= css_attributes.attributes.len) return error.TypeError;
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned(css_attributes.attributes[index].property));
}

/// The attribute's setter: "invoke setProperty() with the first argument
/// being the result of running the IDL attribute to CSS property algorithm"
/// for it, "as second argument the given value, and no third argument. Any
/// exceptions thrown must be re-thrown." Through the generated interface, so
/// [CEReactions] finishes before the setter returns.
pub fn setCssPropertyAttribute(instance: *runtime.Instance, index: usize, value: runtime.DOMString) anyerror!void {
    if (index >= css_attributes.attributes.len) return error.TypeError;
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned(css_attributes.attributes[index].property), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}
