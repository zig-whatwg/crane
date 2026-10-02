//! Auto-generated mixin: LinkStyle
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LinkStyleImpl = @import("impls").LinkStyle;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;

pub const impl = @import("impls").LinkStyle;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "LinkStyle")) {
        if (comptime @hasDecl(impls.LinkStyle, "installHooks")) impls.LinkStyle.installHooks();
    }
}

pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try LinkStyleImpl.get_sheet(instance);
}
