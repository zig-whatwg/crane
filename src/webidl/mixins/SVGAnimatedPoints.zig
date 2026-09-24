//! Auto-generated mixin: SVGAnimatedPoints
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGAnimatedPointsImpl = @import("impls").SVGAnimatedPoints;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGPointList = @import("interfaces").SVGPointList;

pub const impl = @import("impls").SVGAnimatedPoints;

/// Extended attributes: [SameObject]
pub fn get_points(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGAnimatedPointsImpl.get_points(instance);
}

/// Extended attributes: [SameObject]
pub fn get_animatedPoints(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGAnimatedPointsImpl.get_animatedPoints(instance);
}
