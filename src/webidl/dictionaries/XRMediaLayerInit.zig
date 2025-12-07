//! WebIDL dictionary: XRMediaLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const XRMediaLayerInit = struct {
    space: *runtime.Instance,
    layout: ?enums.XRLayerLayout = null,
    invertStereo: ?bool = null,
};
