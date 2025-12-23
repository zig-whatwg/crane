//! Auto-generated mixin: XRViewGeometry
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XRViewGeometryImpl = @import("impls").XRViewGeometry;

// Re-export types from impl
pub const impl = @import("impls").XRViewGeometry;

pub fn get_projectionMatrix(instance: *runtime.Instance) anyerror!void {
    return XRViewGeometryImpl.get_projectionMatrix(instance);
}

pub fn get_transform(instance: *runtime.Instance) !*runtime.Instance {
    return XRViewGeometryImpl.get_transform(instance);
}

