//! WebIDL dictionary: XRNearMeshFeature
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const XRFeatureInit = @import("XRFeatureInit.zig").XRFeatureInit;

pub const XRNearMeshFeature = struct {
    // Inherited from XRFeatureInit
    base: XRFeatureInit,

    quality: ?enums.XRMeshQuality = null,
};
