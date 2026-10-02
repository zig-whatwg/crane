//! Auto-generated mixin: FontFaceSource
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontFaceSourceImpl = @import("impls").FontFaceSource;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const FontFaceSet = @import("interfaces").FontFaceSet;

pub const impl = @import("impls").FontFaceSource;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "FontFaceSource")) {
        if (comptime @hasDecl(impls.FontFaceSource, "installHooks")) impls.FontFaceSource.installHooks();
    }
}

pub fn get_fonts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try FontFaceSourceImpl.get_fonts(instance);
}
