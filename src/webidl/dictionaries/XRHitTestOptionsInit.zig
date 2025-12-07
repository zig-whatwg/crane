//! WebIDL dictionary: XRHitTestOptionsInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const XRHitTestOptionsInit = struct {
    space: *runtime.Instance,
    entityTypes: ?[]const enums.XRHitTestTrackableType = null,
    offsetRay: ?*runtime.Instance = null,
};
