//! WebIDL dictionary: XRWorldMeshFeature
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const XRFeatureInit = @import("XRFeatureInit.zig").XRFeatureInit;

pub const XRWorldMeshFeature = struct {
    // Inherited from XRFeatureInit
    base: XRFeatureInit,

    quality: ?enums.XRMeshQuality = null,
    width: ?f64 = null,
    height: ?f64 = null,
    breadth: ?f64 = null,
};
