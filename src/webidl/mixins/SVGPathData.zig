//! Auto-generated mixin: SVGPathData
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGPathDataImpl = @import("impls").SVGPathData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGPathDataSettings = @import("dictionaries").SVGPathDataSettings;
const SVGPathSegment = @import("interfaces").SVGPathSegment;

pub const impl = @import("impls").SVGPathData;

pub fn call_setPathData(instance: *runtime.Instance, pathData: runtime.JSValue) anyerror!void {
    return try SVGPathDataImpl.call_setPathData(instance, pathData);
}

pub fn call_getPathData(instance: *runtime.Instance, settings: webidl.Opt(SVGPathDataSettings)) anyerror!runtime.JSValue {
    return try SVGPathDataImpl.call_getPathData(instance, settings);
}
