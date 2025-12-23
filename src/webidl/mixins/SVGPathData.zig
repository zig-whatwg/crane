//! Auto-generated mixin: SVGPathData
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGPathDataImpl = @import("impls").SVGPathData;

// Re-export types from impl
pub const impl = @import("impls").SVGPathData;

pub fn call_setPathData(instance: *runtime.Instance, pathData: runtime.JSValue) anyerror!void {
    return SVGPathDataImpl.call_setPathData(instance, pathData);
}

pub fn call_getPathData(instance: *runtime.Instance, settings: dictionaries.SVGPathDataSettings) anyerror!void {
    return SVGPathDataImpl.call_getPathData(instance, settings);
}

