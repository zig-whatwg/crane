//! Auto-generated mixin: TextEncoderCommon
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextEncoderCommonImpl = @import("impls").TextEncoderCommon;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").TextEncoderCommon;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "TextEncoderCommon")) {
        if (comptime @hasDecl(impls.TextEncoderCommon, "installHooks")) impls.TextEncoderCommon.installHooks();
    }
}

pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
    return try TextEncoderCommonImpl.get_encoding(instance);
}
