//! Auto-generated mixin: HTMLOrSVGOrMathMLElement
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLOrSVGOrMathMLElementImpl = @import("impls").HTMLOrSVGOrMathMLElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMStringMap = @import("interfaces").DOMStringMap;
const DOMString = @import("typedefs").DOMString;
const FocusOptions = @import("dictionaries").FocusOptions;

pub const impl = @import("impls").HTMLOrSVGOrMathMLElement;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "HTMLOrSVGOrMathMLElement")) {
        if (comptime @hasDecl(impls.HTMLOrSVGOrMathMLElement, "installHooks")) impls.HTMLOrSVGOrMathMLElement.installHooks();
    }
}

/// Extended attributes: [SameObject]
pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try HTMLOrSVGOrMathMLElementImpl.get_dataset(instance);
}

pub fn get_nonce(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return try HTMLOrSVGOrMathMLElementImpl.get_nonce(instance);
}

pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try HTMLOrSVGOrMathMLElementImpl.set_nonce(instance, value);
}

const reflection = @import("dom").reflection;

/// Extended attributes: [CEReactions], [Reflect]
pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
    if (comptime @hasDecl(HTMLOrSVGOrMathMLElementImpl, "get_autofocus")) return try HTMLOrSVGOrMathMLElementImpl.get_autofocus(instance);
    return try reflection.get(bool, instance, .{ .name = "autofocus" });
}

/// Extended attributes: [CEReactions], [Reflect]
pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    if (comptime @hasDecl(HTMLOrSVGOrMathMLElementImpl, "set_autofocus")) return try HTMLOrSVGOrMathMLElementImpl.set_autofocus(instance, value);
    try reflection.set(bool, instance, .{ .name = "autofocus" }, value);
}

/// Extended attributes: [CEReactions], [ReflectSetter]
pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    return try HTMLOrSVGOrMathMLElementImpl.get_tabIndex(instance);
}

/// Extended attributes: [CEReactions], [ReflectSetter]
pub fn set_tabIndex(instance: *runtime.Instance, value: i32) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    if (comptime @hasDecl(HTMLOrSVGOrMathMLElementImpl, "set_tabIndex")) return try HTMLOrSVGOrMathMLElementImpl.set_tabIndex(instance, value);
    try reflection.set(i32, instance, .{ .name = "tabindex" }, value);
}

pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(FocusOptions)) anyerror!void {
    return try HTMLOrSVGOrMathMLElementImpl.call_focus(instance, options);
}

pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    return try HTMLOrSVGOrMathMLElementImpl.call_blur(instance);
}

/// HTML [CEReactions]: the functions that run a custom element reactions
/// bracket - the binding dispatches each in a catch scope, where
/// engine.withPendingExceptionSetAside sets aside what the member leaves
/// pending.
pub const ce_reactions = .{
    "set_autofocus",
    "set_tabIndex",
};
