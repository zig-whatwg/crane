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

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "SVGAnimatedPoints")) {
        if (comptime @hasDecl(impls.SVGAnimatedPoints, "installHooks")) impls.SVGAnimatedPoints.installHooks();
    }
}

/// Extended attributes: [SameObject]
pub fn get_points(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGAnimatedPointsImpl.get_points(instance);
}

/// Extended attributes: [SameObject]
pub fn get_animatedPoints(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGAnimatedPointsImpl.get_animatedPoints(instance);
}
