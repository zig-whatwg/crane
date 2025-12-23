//! Auto-generated mixin: GeometryUtils
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GeometryUtilsImpl = @import("impls").GeometryUtils;

// Re-export types from impl
pub const impl = @import("impls").GeometryUtils;

pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) !*runtime.Instance {
    return GeometryUtilsImpl.call_convertQuadFromNode(instance, quad, from, options);
}

pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) !*runtime.Instance {
    return GeometryUtilsImpl.call_convertRectFromNode(instance, rect, from, options);
}

pub fn call_getBoxQuads(instance: *runtime.Instance, options: dictionaries.BoxQuadOptions) anyerror!void {
    return GeometryUtilsImpl.call_getBoxQuads(instance, options);
}

pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) !*runtime.Instance {
    return GeometryUtilsImpl.call_convertPointFromNode(instance, point, from, options);
}

