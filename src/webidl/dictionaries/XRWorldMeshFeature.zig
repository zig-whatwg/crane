//! WebIDL dictionary: XRWorldMeshFeature
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRFeatureInit = @import("XRFeatureInit.zig").XRFeatureInit;

pub const XRWorldMeshFeature = struct {
    // Inherited from XRFeatureInit
    base: XRFeatureInit,

    quality: ?anyopaque = null,
    width: ?f64 = null,
    height: ?f64 = null,
    breadth: ?f64 = null,
};
