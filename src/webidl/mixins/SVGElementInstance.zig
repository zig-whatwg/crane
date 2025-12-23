//! Auto-generated mixin: SVGElementInstance
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGElementInstanceImpl = @import("impls").SVGElementInstance;

// Re-export types from impl
pub const impl = @import("impls").SVGElementInstance;

pub fn get_correspondingElement(instance: *runtime.Instance) !?*runtime.Instance {
    return SVGElementInstanceImpl.get_correspondingElement(instance);
}

pub fn get_correspondingUseElement(instance: *runtime.Instance) !?*runtime.Instance {
    return SVGElementInstanceImpl.get_correspondingUseElement(instance);
}

