//! CSSOM §6.4.7: page descriptor IDL attributes use the owning declaration
//! interface. Its page-only dispatch applies descriptor grammar and priority.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
pub const State = interfaces.CSSPageDescriptors.State;
pub const InternalState = struct {};
pub const ImplError = error{InvalidStateError};

pub fn get_margin(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin"));
}
pub fn set_margin(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginTop(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-top"));
}
pub fn set_marginTop(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-top"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginRight(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-right"));
}
pub fn set_marginRight(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-right"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginBottom(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-bottom"));
}
pub fn set_marginBottom(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-bottom"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marginLeft(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-left"));
}
pub fn set_marginLeft(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-left"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_top(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-top"));
}
pub fn set_margin_top(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-top"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_right(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-right"));
}
pub fn set_margin_right(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-right"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_bottom(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-bottom"));
}
pub fn set_margin_bottom(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-bottom"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_margin_left(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("margin-left"));
}
pub fn set_margin_left(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("margin-left"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_size(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("size"));
}
pub fn set_size(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("size"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_pageOrientation(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("page-orientation"));
}
pub fn set_pageOrientation(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("page-orientation"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_page_orientation(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("page-orientation"));
}
pub fn set_page_orientation(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("page-orientation"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_marks(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("marks"));
}
pub fn set_marks(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("marks"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

pub fn get_bleed(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return interfaces.CSSStyleDeclaration.call_getPropertyValue(instance, runtime.DOMString.initInterned("bleed"));
}
pub fn set_bleed(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned("bleed"), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

// The pinned generator still emits these compatibility hooks. This interface
// has only its explicit IDL attributes, never arbitrary CSSStyleProperties.
pub fn call_namedItem(_: *runtime.Instance, _: runtime.DOMString) anyerror!?runtime.DOMString {
    return null;
}
pub fn call_setNamedItem(_: *runtime.Instance, _: runtime.DOMString, _: runtime.DOMString) anyerror!void {}
pub fn getSupportedPropertyNames(_: *runtime.Instance, _: std.mem.Allocator) ![]runtime.DOMString {
    return &.{};
}
