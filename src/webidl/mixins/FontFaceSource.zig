//! Auto-generated mixin: FontFaceSource
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const FontFaceSourceImpl = @import("impls").FontFaceSource;

// Re-export types from impl
pub const impl = @import("impls").FontFaceSource;

pub fn get_fonts(instance: *runtime.Instance) !*runtime.Instance {
    return FontFaceSourceImpl.get_fonts(instance);
}

