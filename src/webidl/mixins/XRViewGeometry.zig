//! Auto-generated mixin: XRViewGeometry
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRViewGeometryImpl = @import("impls").XRViewGeometry;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRRigidTransform = @import("interfaces").XRRigidTransform;

pub const impl = @import("impls").XRViewGeometry;

pub fn get_projectionMatrix(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try XRViewGeometryImpl.get_projectionMatrix(instance);
}

/// Extended attributes: [SameObject]
pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try XRViewGeometryImpl.get_transform(instance);
}
