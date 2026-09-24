//! Auto-generated mixin: SVGFitToViewBox
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGFitToViewBoxImpl = @import("impls").SVGFitToViewBox;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGAnimatedRect = @import("interfaces").SVGAnimatedRect;
const SVGAnimatedPreserveAspectRatio = @import("interfaces").SVGAnimatedPreserveAspectRatio;

pub const impl = @import("impls").SVGFitToViewBox;

/// Extended attributes: [SameObject]
pub fn get_viewBox(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGFitToViewBoxImpl.get_viewBox(instance);
}

/// Extended attributes: [SameObject]
pub fn get_preserveAspectRatio(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGFitToViewBoxImpl.get_preserveAspectRatio(instance);
}
