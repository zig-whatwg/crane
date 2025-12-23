//! Auto-generated mixin: SVGAnimatedPoints
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGAnimatedPointsImpl = @import("impls").SVGAnimatedPoints;

// Re-export types from impl
pub const impl = @import("impls").SVGAnimatedPoints;

pub fn get_points(instance: *runtime.Instance) !*runtime.Instance {
    return SVGAnimatedPointsImpl.get_points(instance);
}

pub fn get_animatedPoints(instance: *runtime.Instance) !*runtime.Instance {
    return SVGAnimatedPointsImpl.get_animatedPoints(instance);
}

