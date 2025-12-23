//! Auto-generated mixin: SVGFitToViewBox
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGFitToViewBoxImpl = @import("impls").SVGFitToViewBox;

// Re-export types from impl
pub const impl = @import("impls").SVGFitToViewBox;

pub fn get_viewBox(instance: *runtime.Instance) !*runtime.Instance {
    return SVGFitToViewBoxImpl.get_viewBox(instance);
}

pub fn get_preserveAspectRatio(instance: *runtime.Instance) !*runtime.Instance {
    return SVGFitToViewBoxImpl.get_preserveAspectRatio(instance);
}

