//! Auto-generated mixin: HTMLHyperlinkElementUtils
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLHyperlinkElementUtilsImpl = @import("impls").HTMLHyperlinkElementUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").HTMLHyperlinkElementUtils;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "HTMLHyperlinkElementUtils")) {
        if (comptime @hasDecl(impls.HTMLHyperlinkElementUtils, "installHooks")) impls.HTMLHyperlinkElementUtils.installHooks();
    }
}

const reflection = @import("dom").reflection;

/// Extended attributes: [CEReactions], [ReflectSetter], [Stringifier]
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLHyperlinkElementUtilsImpl.get_href(instance);
}

/// Extended attributes: [CEReactions], [ReflectSetter], [Stringifier]
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    if (comptime @hasDecl(HTMLHyperlinkElementUtilsImpl, "set_href")) return try HTMLHyperlinkElementUtilsImpl.set_href(instance, value);
    try reflection.set(runtime.USVString, instance, .{ .name = "href" }, value);
}

/// Extended attributes: [CEReactions], [Reflect]
pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (comptime @hasDecl(HTMLHyperlinkElementUtilsImpl, "get_target")) return try HTMLHyperlinkElementUtilsImpl.get_target(instance);
    return try reflection.get(runtime.DOMString, instance, .{ .name = "target" });
}

/// Extended attributes: [CEReactions], [Reflect]
pub fn set_target(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    if (comptime @hasDecl(HTMLHyperlinkElementUtilsImpl, "set_target")) return try HTMLHyperlinkElementUtilsImpl.set_target(instance, value);
    try reflection.set(runtime.DOMString, instance, .{ .name = "target" }, value);
}

/// HTML [CEReactions]: the functions that run a custom element reactions
/// bracket - the binding dispatches each in a catch scope, where
/// engine.withPendingExceptionSetAside sets aside what the member leaves
/// pending.
pub const ce_reactions = .{
    "set_href",
    "set_target",
};
