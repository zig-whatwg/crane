//! Auto-generated mixin: HTMLOrSVGElement
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLOrSVGElementImpl = @import("impls").HTMLOrSVGElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMStringMap = @import("interfaces").DOMStringMap;
const DOMString = @import("typedefs").DOMString;
const FocusOptions = @import("dictionaries").FocusOptions;

pub const impl = @import("impls").HTMLOrSVGElement;

/// Extended attributes: [SameObject]
pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try HTMLOrSVGElementImpl.get_dataset(instance);
}

pub fn get_nonce(instance: *runtime.Instance) anyerror!DOMString {
    return try HTMLOrSVGElementImpl.get_nonce(instance);
}

pub fn set_nonce(instance: *runtime.Instance, value: DOMString) anyerror!void {
    try HTMLOrSVGElementImpl.set_nonce(instance, value);
}

/// Extended attributes: [CEReactions], [Reflect]
const reflection = @import("impls").reflection;

pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
    if (comptime @hasDecl(HTMLOrSVGElementImpl, "get_autofocus")) return try HTMLOrSVGElementImpl.get_autofocus(instance);
    return try reflection.get(bool, instance, .{ .name = "autofocus" });
}

/// Extended attributes: [CEReactions], [Reflect]
pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    if (comptime @hasDecl(HTMLOrSVGElementImpl, "set_autofocus")) return try HTMLOrSVGElementImpl.set_autofocus(instance, value);
    try reflection.set(bool, instance, .{ .name = "autofocus" }, value);
}

/// Extended attributes: [CEReactions], [ReflectSetter]
pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    return try HTMLOrSVGElementImpl.get_tabIndex(instance);
}

/// Extended attributes: [CEReactions], [ReflectSetter]
pub fn set_tabIndex(instance: *runtime.Instance, value: i32) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    if (comptime @hasDecl(HTMLOrSVGElementImpl, "set_tabIndex")) return try HTMLOrSVGElementImpl.set_tabIndex(instance, value);
    try reflection.set(i32, instance, .{ .name = "tabindex" }, value);
}

pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(FocusOptions)) anyerror!void {
    return try HTMLOrSVGElementImpl.call_focus(instance, options);
}

pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    return try HTMLOrSVGElementImpl.call_blur(instance);
}
