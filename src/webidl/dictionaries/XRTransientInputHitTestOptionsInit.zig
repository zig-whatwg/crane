//! WebIDL dictionary: XRTransientInputHitTestOptionsInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const XRTransientInputHitTestOptionsInit = struct {
    profile: runtime.DOMString,
    entityTypes: ?[]const enums.XRHitTestTrackableType = null,
    offsetRay: ?*runtime.Instance = null,
};
