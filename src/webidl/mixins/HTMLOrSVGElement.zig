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

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "HTMLOrSVGElement")) {
        if (comptime @hasDecl(impls.HTMLOrSVGElement, "installHooks")) impls.HTMLOrSVGElement.installHooks();
    }
}

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

const reflection = @import("impls").reflection;

/// Extended attributes: [CEReactions], [Reflect]
pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
    if (comptime @hasDecl(HTMLOrSVGElementImpl, "get_autofocus")) return try HTMLOrSVGElementImpl.get_autofocus(instance);
    return try reflection.get(bool, instance, .{ .name = "autofocus" });
}

/// Extended attributes: [CEReactions], [Reflect]
pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

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
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    if (comptime @hasDecl(HTMLOrSVGElementImpl, "set_tabIndex")) return try HTMLOrSVGElementImpl.set_tabIndex(instance, value);
    try reflection.set(i32, instance, .{ .name = "tabindex" }, value);
}

pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(FocusOptions)) anyerror!void {
    return try HTMLOrSVGElementImpl.call_focus(instance, options);
}

pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    return try HTMLOrSVGElementImpl.call_blur(instance);
}

/// HTML [CEReactions]: the functions that run a custom element reactions
/// bracket - the binding dispatches each in a catch scope, where
/// engine.takePendingException can take what the member leaves pending.
pub const ce_reactions = .{
    "set_autofocus",
    "set_tabIndex",
};
